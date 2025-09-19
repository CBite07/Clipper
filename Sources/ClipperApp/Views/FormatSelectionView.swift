import SwiftUI

struct FormatSelectionView: View {
    let urlString: String
    let formats: [FormatDescriptor]
    @Binding var selectedFormat: FormatDescriptor?
    let confirmAction: () -> Void
    let cancelAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("포맷 선택")
                .font(.title2.bold())
            Text(urlString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            List(formats) { format in
                FormatRow(format: format, isSelected: format.id == selectedFormat?.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedFormat = format
                    }
            }
            .frame(minHeight: 240)

            HStack {
                Spacer()
                Button("취소", role: .cancel) {
                    cancelAction()
                }
                Button("다운로드") {
                    confirmAction()
                }
                .disabled(selectedFormat == nil)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480, height: 420)
    }
}

private struct FormatRow: View {
    let format: FormatDescriptor
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(format.description)
                    .font(.body)
                Text("확장자: .\(format.fileExtension)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

struct FormatSelectionView_Previews: PreviewProvider {
    @State static var selected: FormatDescriptor? = .init(id: "best",
                                                          description: "best • 1080p",
                                                          fileExtension: "mp4",
                                                          resolution: "1080p",
                                                          note: "Best quality")

    static var previews: some View {
        FormatSelectionView(urlString: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                             formats: [selected!],
                             selectedFormat: $selected,
                             confirmAction: {},
                             cancelAction: {})
    }
}
