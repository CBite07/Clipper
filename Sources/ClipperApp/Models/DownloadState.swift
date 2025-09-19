import Foundation

enum DownloadState: Equatable {
    case queued
    case preparing
    case downloading(progress: Double, eta: TimeInterval?)
    case finished(fileURL: URL)
    case failed(reason: String)
    case cancelled

    var isTerminal: Bool {
        switch self {
        case .finished, .failed, .cancelled:
            return true
        default:
            return false
        }
    }

    var progress: Double {
        switch self {
        case let .downloading(progress, _):
            return progress
        case .finished:
            return 1.0
        default:
            return 0.0
        }
    }
}
