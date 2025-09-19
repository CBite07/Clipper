import SwiftUI

@main
struct ClipperApp: App {
    @StateObject private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: dependencies.downloadQueueViewModel,
                        settingsViewModel: dependencies.settingsViewModel)
                .environmentObject(dependencies.downloadQueueViewModel)
                .environmentObject(dependencies.settingsViewModel)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 960, height: 620)

        Settings {
            SettingsView(viewModel: dependencies.settingsViewModel)
                .frame(width: 480, height: 360)
        }
    }
}
