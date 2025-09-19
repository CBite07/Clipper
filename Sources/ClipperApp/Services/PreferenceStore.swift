import Combine
import Foundation

@MainActor
final class PreferenceStore: ObservableObject {
    @Published private(set) var configuration: DownloadConfiguration

    private enum StorageKeys {
        static let configuration = "clipper.configuration"
    }

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if let stored = userDefaults.data(forKey: StorageKeys.configuration),
           let decoded = try? decoder.decode(CodableConfiguration.self, from: stored) {
            self.configuration = decoded.model
        } else if let bundledConfiguration = PreferenceStore.loadBundledConfiguration() {
            self.configuration = bundledConfiguration
        } else {
            self.configuration = .default
        }

        ensureDownloadDirectoryExists()
    }

    func update(_ block: (inout DownloadConfiguration) -> Void) {
        block(&configuration)
        persist()
    }

    func setDownloadDirectory(_ url: URL) {
        update { configuration in
            configuration.downloadDirectory = url
        }
        ensureDownloadDirectoryExists()
    }

    func setFormatPreference(_ preference: DownloadConfiguration.FormatPreference) {
        update { configuration in
            configuration.formatPreference = preference
            configuration.shouldPromptForFormat = (preference == .askEveryTime)
        }
    }

    func setPromptForFormat(_ newValue: Bool) {
        update { configuration in
            configuration.shouldPromptForFormat = newValue
        }
    }

    private func persist() {
        let codable = CodableConfiguration(model: configuration)
        if let data = try? encoder.encode(codable) {
            userDefaults.set(data, forKey: StorageKeys.configuration)
        }
    }

    private func ensureDownloadDirectoryExists() {
        let directory = configuration.downloadDirectory
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            Logger.general.error("Failed to create download directory: \(error.localizedDescription)")
        }
    }

    private static func loadBundledConfiguration() -> DownloadConfiguration? {
        guard let resourceURL = Bundle.module.url(forResource: "default-preferences", withExtension: "json") else {
            return nil
        }

        do {
            let data = try Data(contentsOf: resourceURL)
            let dto = try JSONDecoder().decode(CodableConfiguration.self, from: data)
            return dto.model
        } catch {
            Logger.general.error("Failed to decode bundled configuration: \(error.localizedDescription)")
            return nil
        }
    }
}

private struct CodableConfiguration: Codable {
    var downloadDirectory: String
    var preferredFormat: DownloadConfiguration.FormatPreference
    var autoPromptFormat: Bool

    init(model: DownloadConfiguration) {
        self.downloadDirectory = model.downloadDirectory.path
        self.preferredFormat = model.formatPreference
        self.autoPromptFormat = model.shouldPromptForFormat
    }

    var model: DownloadConfiguration {
        let url = URL(fileURLWithPath: downloadDirectory).standardizedFileURL
        return DownloadConfiguration(downloadDirectory: url,
                                     formatPreference: preferredFormat,
                                     shouldPromptForFormat: autoPromptFormat)
    }
}
