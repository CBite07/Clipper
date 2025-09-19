import Combine
import Foundation
import SwiftUI

@MainActor
final class AppDependencies: ObservableObject {
    let preferenceStore: PreferenceStore
    let downloadManager: DownloadManager
    let downloadQueueViewModel: DownloadQueueViewModel
    let settingsViewModel: SettingsViewModel
    private let spotlightBridge: SpotlightBridge
    private let notificationManager: NotificationManager

    init() {
        let preferenceStore = PreferenceStore()
        self.preferenceStore = preferenceStore

        let notificationManager = NotificationManager.shared
        self.notificationManager = notificationManager
        notificationManager.requestAuthorization()

        let downloadManager = DownloadManager(preferenceStore: preferenceStore,
                                              notificationManager: notificationManager)
        self.downloadManager = downloadManager

        let queueViewModel = DownloadQueueViewModel(manager: downloadManager,
                                                    preferenceStore: preferenceStore)
        self.downloadQueueViewModel = queueViewModel

        let settingsViewModel = SettingsViewModel(preferenceStore: preferenceStore)
        self.settingsViewModel = settingsViewModel

        self.spotlightBridge = SpotlightBridge { url in
            Task { [weak downloadManager] in
                await downloadManager?.handleIncoming(url: url)
            }
        }

        self.spotlightBridge.start()
    }
}
