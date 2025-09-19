import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section(header: Text("기본 저장 위치")) {
                HStack {
                    Text(viewModel.configuration.downloadDirectory.path)
                        .font(.callout)
                        .textSelection(.enabled)
                    Spacer()
                    Button("변경…") {
                        selectDownloadDirectory()
                    }
                }
            }

            Section(header: Text("기본 다운로드 포맷")) {
                Picker("포맷", selection: Binding(get: {
                    viewModel.configuration.formatPreference == .askEveryTime ? .best : viewModel.configuration.formatPreference
                }, set: { newValue in
                    viewModel.updateFormatPreference(newValue)
                })) {
                    ForEach(DownloadConfiguration.FormatPreference.allCases.filter { $0 != .askEveryTime }) { preference in
                        Text(preference.description)
                            .tag(preference)
                    }
                }
                .pickerStyle(.radioGroup)
                Toggle("다운로드 시마다 포맷 선택", isOn: Binding(get: {
                    viewModel.configuration.shouldPromptForFormat
                }, set: { newValue in
                    viewModel.togglePromptForFormat(newValue)
                }))
            }

            Section(header: Text("도구 상태")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("앱은 번들된 yt-dlp 및 ffmpeg 바이너리를 사용합니다. 최신 버전으로 교체하려면 개발자 웹사이트에서 제공하는 지침을 따르세요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(width: 520)
    }

    private func selectDownloadDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "선택"
        panel.directoryURL = viewModel.configuration.downloadDirectory
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.updateDownloadDirectory(url)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let preferenceStore = PreferenceStore()
        let settingsViewModel = SettingsViewModel(preferenceStore: preferenceStore)
        SettingsView(viewModel: settingsViewModel)
    }
}
