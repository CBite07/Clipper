import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var configuration: DownloadConfiguration

    private let preferenceStore: PreferenceStore

    init(preferenceStore: PreferenceStore) {
        self.preferenceStore = preferenceStore
        self.configuration = preferenceStore.configuration

        preferenceStore.$configuration
            .receive(on: RunLoop.main)
            .assign(to: &self.$configuration)
    }

    func updateDownloadDirectory(_ url: URL) {
        preferenceStore.setDownloadDirectory(url)
    }

    func updateFormatPreference(_ preference: DownloadConfiguration.FormatPreference) {
        preferenceStore.setFormatPreference(preference)
    }

    func togglePromptForFormat(_ newValue: Bool) {
        preferenceStore.setPromptForFormat(newValue)
    }
}
