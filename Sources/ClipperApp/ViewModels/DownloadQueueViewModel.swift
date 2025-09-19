import AppKit
import Combine
import Foundation

@MainActor
final class DownloadQueueViewModel: ObservableObject {
    @Published private(set) var queued: [DownloadTask] = []
    @Published private(set) var active: [DownloadTask] = []
    @Published private(set) var completed: [DownloadTask] = []

    @Published var urlInput: String = ""
    @Published var isShowingFormatSheet: Bool = false
    @Published var availableFormats: [FormatDescriptor] = []
    @Published var selectedFormat: FormatDescriptor?
    @Published var formatPreviewTitle: String = ""
    @Published var pendingFormatURL: URL?

    private let manager: DownloadManager
    private let preferenceStore: PreferenceStore
    init(manager: DownloadManager, preferenceStore: PreferenceStore) {
        self.manager = manager
        self.preferenceStore = preferenceStore

        manager.$queuedTasks
            .map { Array($0.values) }
            .receive(on: RunLoop.main)
            .assign(to: &self.$queued)

        manager.$activeTasks
            .map { Array($0.values) }
            .receive(on: RunLoop.main)
            .assign(to: &self.$active)

        manager.$completedTasks
            .map { Array($0.values).sorted { $0.createdAt > $1.createdAt } }
            .receive(on: RunLoop.main)
            .assign(to: &self.$completed)
    }

    func submitURL() {
        let trimmed = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), !trimmed.isEmpty else { return }

        if preferenceStore.configuration.shouldPromptForFormat {
            Task {
                await loadFormats(for: url)
            }
        } else {
            let format = preferenceStore.configuration.formatPreference.ytDlpFormatIdentifier
            enqueue(url: url, format: format)
        }

        urlInput = ""
    }

    func enqueue(url: URL, format: String, mediaType: DownloadTask.MediaType? = nil) {
        let mediaType = mediaType ?? (format.contains("audio") ? .audio : .video)
        let request = DownloadRequest(url: url,
                                      format: format,
                                      mediaType: mediaType,
                                      source: .manual)
        manager.enqueue(request: request)
    }

    func cancel(task: DownloadTask) {
        manager.cancel(taskID: task.id)
    }

    func retry(task: DownloadTask) {
        manager.retry(taskID: task.id)
    }

    func remove(task: DownloadTask) {
        manager.removeCompleted(taskID: task.id)
    }

    func clearHistory() {
        manager.clearCompleted()
    }

    func openInFinder(task: DownloadTask) {
        guard case let .finished(fileURL) = task.state else { return }
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    func showFormatSheet(for url: URL) {
        Task { await loadFormats(for: url) }
    }

    private func loadFormats(for url: URL) async {
        formatPreviewTitle = url.absoluteString
        pendingFormatURL = url
        do {
            availableFormats = try await manager.availableFormats(for: url)
            selectedFormat = availableFormats.first
            isShowingFormatSheet = true
        } catch {
            Logger.download.error("Failed to load formats: \(error.localizedDescription)")
            enqueue(url: url, format: preferenceStore.configuration.formatPreference.ytDlpFormatIdentifier)
            pendingFormatURL = nil
        }
    }

    func confirmFormatSelection() {
        guard let selectedFormat, let url = pendingFormatURL else { return }
        enqueue(url: url, format: selectedFormat.id)
        isShowingFormatSheet = false
        pendingFormatURL = nil
        self.selectedFormat = nil
    }

    func cancelFormatSelection() {
        isShowingFormatSheet = false
        pendingFormatURL = nil
        selectedFormat = nil
    }
}
