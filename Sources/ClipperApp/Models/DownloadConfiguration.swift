import Foundation

struct DownloadConfiguration: Codable, Equatable {
    enum FormatPreference: String, Codable, CaseIterable, Identifiable {
        case best
        case highDefinition
        case audioOnly
        case askEveryTime

        var id: String { rawValue }

        var ytDlpFormatIdentifier: String {
            switch self {
            case .best: return "best"
            case .highDefinition: return "bestvideo[height<=1080]+bestaudio/best"
            case .audioOnly: return "bestaudio/best"
            case .askEveryTime: return "best"
            }
        }

        var description: String {
            switch self {
            case .best:
                return "최고 화질 (가능한 최고 해상도의 영상과 오디오)"
            case .highDefinition:
                return "1080p 이하의 고화질 영상"
            case .audioOnly:
                return "오디오만 추출 (M4A)"
            case .askEveryTime:
                return "항상 포맷 선택"
            }
        }
    }

    var downloadDirectory: URL
    var formatPreference: FormatPreference
    var shouldPromptForFormat: Bool

    static let `default`: DownloadConfiguration = {
        let directory = FileManager.default
            .homeDirectoryForCurrentUser
            .appending(path: "Downloads/SpotlightDownloader", directoryHint: .isDirectory)
        return .init(downloadDirectory: directory,
                     formatPreference: .best,
                     shouldPromptForFormat: false)
    }()
}
