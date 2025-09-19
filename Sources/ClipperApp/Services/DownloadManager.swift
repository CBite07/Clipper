import Combine
import Foundation
import OrderedCollections

@MainActor
final class DownloadManager: ObservableObject {
    @Published private(set) var queuedTasks: OrderedDictionary<UUID, DownloadTask> = [:]
    @Published private(set) var activeTasks: OrderedDictionary<UUID, DownloadTask> = [:]
    @Published private(set) var completedTasks: OrderedDictionary<UUID, DownloadTask> = [:]

    private let preferenceStore: PreferenceStore
    private let notificationManager: NotificationManager?
    private let workerQueue = DispatchQueue(label: "com.spotlightdownloader.clipper.download", qos: .userInitiated)
    private var processes: [UUID: Process] = [:]
    private var outputBuffers: [UUID: String] = [:]
    private var toolchain: DownloadToolchain?
    private let maxConcurrentDownloads = 2

    init(preferenceStore: PreferenceStore, notificationManager: NotificationManager? = nil) {
        self.preferenceStore = preferenceStore
        self.notificationManager = notificationManager
        Task { [weak self] in
            await self?.refreshToolchain()
        }
    }

    func handleIncoming(url: URL) async {
        let configuration = preferenceStore.configuration
        let format = configuration.formatPreference.ytDlpFormatIdentifier
        let mediaType: DownloadTask.MediaType = configuration.formatPreference == .audioOnly ? .audio : .video
        let request = DownloadRequest(url: url, format: format, mediaType: mediaType, source: .spotlight)
        enqueue(request: request)
    }

    @discardableResult
    func enqueue(request: DownloadRequest) -> DownloadTask {
        var task = DownloadTask(url: request.url,
                                title: request.customTitle ?? request.url.absoluteString,
                                state: .queued,
                                formatIdentifier: request.format,
                                mediaType: request.mediaType)
        queuedTasks[task.id] = task
        Logger.download.info("Enqueued download: \(task.url)")
        fetchMetadata(for: task.id, url: task.url)
        processQueue()
        return task
    }

    func cancel(taskID: UUID) {
        if let process = processes[taskID] {
            process.terminate()
            processes[taskID] = nil
        }
        if var task = activeTasks[taskID] {
            task.state = .cancelled
            activeTasks[taskID] = nil
            completedTasks[taskID] = task
        } else if queuedTasks[taskID] != nil {
            var task = queuedTasks.removeValue(forKey: taskID)
            task?.state = .cancelled
            if let task { completedTasks[task.id] = task }
        }
        processQueue()
    }

    func retry(taskID: UUID) {
        guard let completed = completedTasks[taskID] else { return }
        var retried = completed
        retried.state = .queued
        retried.destinationURL = nil
        completedTasks[taskID] = nil
        queuedTasks[retried.id] = retried
        processQueue()
    }

    func removeCompleted(taskID: UUID) {
        completedTasks[taskID] = nil
    }

    func clearCompleted() {
        completedTasks.removeAll()
    }

    func refreshToolchain() async {
        do {
            self.toolchain = try DownloadToolchain(bundle: .main)
        } catch {
            Logger.download.error("Toolchain discovery failed: \(error.localizedDescription)")
        }
    }

    func availableFormats(for url: URL) async throws -> [FormatDescriptor] {
        let toolchain = try toolchainOrThrow()
        return try await withCheckedThrowingContinuation { continuation in
            workerQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: [])
                    return
                }
                let process = Process()
                process.executableURL = toolchain.ytDlpURL
                process.arguments = ["--list-formats", url.absoluteString]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                process.terminationHandler = { _ in
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(decoding: data, as: UTF8.self)
                    let formats = self.parseFormats(from: output)
                    continuation.resume(returning: formats)
                }
            }
        }
    }

    private func processQueue() {
        while activeTasks.count < maxConcurrentDownloads, let next = queuedTasks.first {
            queuedTasks[next.key] = nil
            var task = next.value
            task.state = .preparing
            activeTasks[task.id] = task
            start(task: task)
        }
    }

    private func start(task: DownloadTask) {
        guard let toolchain = try? toolchainOrThrow() else {
            markFailure(taskID: task.id, reason: "다운로드 도구를 찾을 수 없습니다.")
            return
        }

        workerQueue.async { [weak self] in
            guard let self else { return }
            let process = Process()
            process.executableURL = toolchain.ytDlpURL
            var arguments = ["--newline",
                             "--no-mtime"]
            if let ffmpegURL = toolchain.ffmpegURL {
                arguments += ["--ffmpeg-location", ffmpegURL.path]
            }
            arguments += ["-f", task.formatIdentifier,
                          "-o", self.outputTemplate(for: task),
                          task.url.absoluteString]
            process.arguments = arguments

            let pipe = Pipe()
            process.standardError = pipe
            process.standardOutput = Pipe()
            self.processes[task.id] = process
            self.outputBuffers[task.id] = ""

            pipe.fileHandleForReading.readabilityHandler = { handle in
                self?.handleOutput(for: task.id, data: handle.availableData)
            }

            process.terminationHandler = { process in
                pipe.fileHandleForReading.readabilityHandler = nil
                self?.handleTermination(of: task.id, process: process)
            }

            do {
                try process.run()
                Logger.download.info("Started yt-dlp for \(task.url)")
                Task { @MainActor [weak self] in
                    self?.update(taskID: task.id) { task in
                        task.state = .downloading(progress: 0, eta: nil)
                    }
                }
            } catch {
                Task { @MainActor [weak self] in
                    self?.markFailure(taskID: task.id, reason: error.localizedDescription)
                }
            }
        }
    }

    private func handleOutput(for taskID: UUID, data: Data) {
        guard !data.isEmpty else { return }
        let chunk = String(decoding: data, as: UTF8.self)
        outputBuffers[taskID, default: ""] += chunk
        var buffer = outputBuffers[taskID] ?? ""
        while let range = buffer.range(of: "\n") {
            let line = String(buffer[..<range.lowerBound])
            buffer = String(buffer[range.upperBound...])
            parse(line: line, for: taskID)
        }
        outputBuffers[taskID] = buffer
    }

    private func parse(line: String, for taskID: UUID) {
        if let match = YTDLPProgressParser.parseProgress(from: line) {
            Task { @MainActor [weak self] in
                self?.update(taskID: taskID) { task in
                    task.state = .downloading(progress: match.progress, eta: match.eta)
                }
            }
        } else if line.contains("Destination:") {
            let components = line.split(separator: " ", maxSplits: 1).map(String.init)
            if components.count == 2 {
                let path = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let url = URL(fileURLWithPath: path)
                Task { @MainActor [weak self] in
                    self?.update(taskID: taskID) { task in
                        task.destinationURL = url
                    }
                }
            }
        }
    }

    private func fetchMetadata(for taskID: UUID, url: URL) {
        workerQueue.async { [weak self] in
            guard let self else { return }
            guard let toolchain = try? self.toolchainOrThrow() else { return }
            let process = Process()
            process.executableURL = toolchain.ytDlpURL
            process.arguments = ["--skip-download", "--print-json", url.absoluteString]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            do {
                try process.run()
            } catch {
                Logger.download.error("Metadata fetch failed to start: \(error.localizedDescription)")
                return
            }

            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard
                let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return }

            let title = jsonObject["title"] as? String
            let thumbnailString = jsonObject["thumbnail"] as? String
            let parsedThumbnail = thumbnailString.flatMap { URL(string: $0) }

            Task { @MainActor [weak self] in
                self?.update(taskID: taskID) { task in
                    if let title {
                        task.title = title
                    }
                    task.thumbnailURL = parsedThumbnail
                }
            }
        }
    }

    private func handleTermination(of taskID: UUID, process: Process) {
        Task { @MainActor in
            self.processes[taskID] = nil
            let terminationReason = process.terminationReason
            if process.terminationStatus == 0 {
                if var task = activeTasks.removeValue(forKey: taskID) {
                    if case let .downloading(_, _) = task.state,
                       let destination = task.destinationURL {
                        task.state = .finished(fileURL: destination)
                    } else {
                        task.state = .finished(fileURL: preferenceStore.configuration.downloadDirectory)
                    }
                    completedTasks[taskID] = task
                    Logger.download.info("Finished download: \(task.url)")
                    notificationManager?.postCompletionNotification(for: task)
                }
            } else {
                let reason = "다운로드 실패 (코드: \(process.terminationStatus), 이유: \(terminationReason.rawValue))"
                markFailure(taskID: taskID, reason: reason)
            }
            processQueue()
        }
    }

    private func markFailure(taskID: UUID, reason: String) {
        if var task = activeTasks.removeValue(forKey: taskID) {
            task.state = .failed(reason: reason)
            completedTasks[taskID] = task
            notificationManager?.postFailureNotification(for: task, reason: reason)
        } else if var queued = queuedTasks.removeValue(forKey: taskID) {
            queued.state = .failed(reason: reason)
            completedTasks[taskID] = queued
            notificationManager?.postFailureNotification(for: queued, reason: reason)
        } else if var existing = completedTasks[taskID] {
            existing.state = .failed(reason: reason)
            completedTasks[taskID] = existing
            notificationManager?.postFailureNotification(for: existing, reason: reason)
        }
        Logger.download.error("Task \(taskID) failed: \(reason)")
        processQueue()
    }

    private func update(taskID: UUID, mutation: (inout DownloadTask) -> Void) {
        if var task = activeTasks[taskID] {
            mutation(&task)
            activeTasks[taskID] = task
        } else if var task = queuedTasks[taskID] {
            mutation(&task)
            queuedTasks[taskID] = task
        } else if var task = completedTasks[taskID] {
            mutation(&task)
            completedTasks[taskID] = task
        }
    }

    private func outputTemplate(for task: DownloadTask) -> String {
        let directory = preferenceStore.configuration.downloadDirectory
        let filename = "%(title)s.%(ext)s"
        return directory.appendingPathComponent(filename).path
    }

    private func toolchainOrThrow() throws -> DownloadToolchain {
        if let toolchain { return toolchain }
        let resolved = try DownloadToolchain(bundle: .main)
        self.toolchain = resolved
        return resolved
    }

    private func parseFormats(from output: String) -> [FormatDescriptor] {
        let lines = output.split(separator: "\n").map(String.init)
        guard let headerIndex = lines.firstIndex(where: { $0.contains("format code") }) else { return [] }
        let formatLines = lines[(headerIndex + 1)...]
        return formatLines.compactMap { line -> FormatDescriptor? in
            let components = line.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true).map(String.init)
            guard components.count >= 4 else { return nil }
            let id = components[0]
            let extensionComponent = components[1]
            let resolution = components[2]
            let note = components[3...].joined(separator: " ")
            let description = "\(id) • \(resolution) • \(note)"
            return FormatDescriptor(id: id,
                                    description: description,
                                    fileExtension: extensionComponent,
                                    resolution: resolution,
                                    note: note)
        }
    }
}
