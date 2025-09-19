import Foundation

enum DownloadToolchainError: Error, LocalizedError {
    case missingExecutable(String)

    var errorDescription: String? {
        switch self {
        case let .missingExecutable(name):
            return "\(name) 실행 파일을 찾을 수 없습니다. 앱 설정에서 번들 파일을 확인해 주세요."
        }
    }
}

struct DownloadToolchain {
    let ytDlpURL: URL
    let ffmpegURL: URL?

    init(bundle: Bundle = .main) throws {
        self.ytDlpURL = try DownloadToolchain.locateExecutable(named: "yt-dlp", in: bundle)
        self.ffmpegURL = try? DownloadToolchain.locateExecutable(named: "ffmpeg", in: bundle)
    }

    static func locateExecutable(named name: String, in bundle: Bundle) throws -> URL {
        let possibleNames = [name, name + "-macos"]
        for candidate in possibleNames {
            if let bundled = bundle.url(forResource: candidate, withExtension: nil) ?? Bundle.module.url(forResource: candidate, withExtension: nil) {
                return bundled
            }
        }

        let searchPaths = ["/usr/local/bin/\(name)", "/opt/homebrew/bin/\(name)", "/opt/local/bin/\(name)", "/usr/bin/\(name)"]
        if let path = searchPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return URL(fileURLWithPath: path)
        }

        throw DownloadToolchainError.missingExecutable(name)
    }
}
