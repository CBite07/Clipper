import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: DownloadQueueViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel

    var body: some View {
        NavigationView {
            sidebar
            history
        }
        .frame(minWidth: 900, minHeight: 560)
        .sheet(isPresented: $viewModel.isShowingFormatSheet) {
            if let pendingURL = viewModel.pendingFormatURL {
                FormatSelectionView(urlString: pendingURL.absoluteString,
                                     formats: viewModel.availableFormats,
                                     selectedFormat: Binding(get: {
                    viewModel.selectedFormat
                }, set: { newValue in
                    viewModel.selectedFormat = newValue
                }),
                                     confirmAction: {
                    viewModel.confirmFormatSelection()
                },
                                     cancelAction: {
                    viewModel.cancelFormatSelection()
                })
            } else {
                ProgressView("포맷 정보를 불러오는 중...")
                    .padding()
            }
        }
    }

    private var sidebar: some View {
        List {
            Section("URL 입력") {
                VStack(spacing: 8) {
                    TextField("유튜브 URL을 붙여넣고 Enter", text: $viewModel.urlInput)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { viewModel.submitURL() }
                    HStack {
                        Button(action: viewModel.submitURL) {
                            Label("다운로드 추가", systemImage: "arrow.down.circle")
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(viewModel.urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button(action: pasteFromClipboard) {
                            Label("클립보드 붙여넣기", systemImage: "doc.on.clipboard")
                        }
                    }
                }
            }

            if !viewModel.active.isEmpty {
                Section("다운로드 중") {
                    ForEach(viewModel.active) { task in
                        DownloadRowView(task: task,
                                        cancelAction: { viewModel.cancel(task: task) })
                    }
                }
            }

            if !viewModel.queued.isEmpty {
                Section("대기열") {
                    ForEach(viewModel.queued) { task in
                        DownloadRowView(task: task,
                                        cancelAction: { viewModel.cancel(task: task) })
                    }
                }
            }

            if viewModel.active.isEmpty && viewModel.queued.isEmpty {
                Section {
                    ContentUnavailableView("대기 중인 작업이 없습니다",
                                            systemImage: "tray",
                                            description: Text("URL을 추가하면 자동으로 다운로드가 시작됩니다."))
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("다운로드")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: openSettings) {
                    Label("설정", systemImage: "gear")
                }
            }
        }
    }

    private var history: some View {
        List {
            Section("완료 내역") {
                if viewModel.completed.isEmpty {
                    ContentUnavailableView("완료된 항목이 없습니다",
                                            systemImage: "clock.arrow.circlepath",
                                            description: Text("다운로드가 완료되면 이곳에 표시됩니다."))
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach(viewModel.completed) { task in
                        DownloadRowView(task: task,
                                        retryAction: { viewModel.retry(task: task) },
                                        openAction: { viewModel.openInFinder(task: task) },
                                        removeAction: { viewModel.remove(task: task) })
                    }
                }
            }
        }
        .navigationTitle("기록")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("기록 비우기") {
                    viewModel.clearHistory()
                }
                .disabled(viewModel.completed.isEmpty)
            }
        }
    }

    private func pasteFromClipboard() {
        if let clipboard = NSPasteboard.general.string(forType: .string) {
            viewModel.urlInput = clipboard
        }
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let preferenceStore = PreferenceStore()
        let manager = DownloadManager(preferenceStore: preferenceStore,
                                      notificationManager: NotificationManager.shared)
        let queueViewModel = DownloadQueueViewModel(manager: manager, preferenceStore: preferenceStore)
        let settingsViewModel = SettingsViewModel(preferenceStore: preferenceStore)
        return ContentView(viewModel: queueViewModel, settingsViewModel: settingsViewModel)
    }
}
