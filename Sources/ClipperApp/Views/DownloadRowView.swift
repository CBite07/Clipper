import SwiftUI

struct DownloadRowView: View {
    let task: DownloadTask
    var cancelAction: (() -> Void)?
    var retryAction: (() -> Void)?
    var openAction: (() -> Void)?
    var removeAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center) {
                if let thumbnailURL = task.thumbnailURL {
                    AsyncImage(url: thumbnailURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .overlay(
                                ProgressView()
                            )
                    }
                    .frame(width: 64, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle)
                        .font(.headline)
                        .lineLimit(2)
                    Text(task.url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                statusControls
            }
            progressView
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var progressView: some View {
        switch task.state {
        case .queued:
            Label("대기 중", systemImage: "clock")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .preparing:
            Label("준비 중", systemImage: "bolt.badge.clock")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case let .downloading(progress, eta):
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: progress)
                if let eta {
                    Text("남은 시간: \(format(eta: eta))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        case let .finished(fileURL):
            HStack {
                Label("완료", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
                Spacer()
                Button("Finder에서 보기") {
                    openAction?()
                }
                .buttonStyle(.borderless)
            }
        case let .failed(reason):
            HStack {
                Label("실패", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        case .cancelled:
            Label("취소됨", systemImage: "xmark.circle")
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var statusControls: some View {
        switch task.state {
        case .queued, .preparing, .downloading:
            Button(role: .cancel) {
                cancelAction?()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
        case .failed:
            Button("재시도") {
                retryAction?()
            }
            .buttonStyle(.borderless)
        case .finished:
            Button(role: .destructive) {
                removeAction?()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        case .cancelled:
            Button(role: .destructive) {
                removeAction?()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }

    private var displayTitle: String {
        task.title.isEmpty ? task.url.lastPathComponent : task.title
    }

    private func format(eta: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: eta) ?? "--"
    }
}

struct DownloadRowView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            DownloadRowView(task: .init(url: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!,
                                         title: "샘플 다운로드",
                                         state: .downloading(progress: 0.42, eta: 120)))
        }
        .frame(width: 420)
    }
}
