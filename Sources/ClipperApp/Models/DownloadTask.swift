import Foundation

struct DownloadTask: Identifiable, Equatable {
    enum MediaType: String, Codable, CaseIterable, Identifiable {
        case video
        case audio

        var id: String { rawValue }
    }

    let id: UUID
    let url: URL
    var title: String
    var thumbnailURL: URL?
    var createdAt: Date
    var state: DownloadState
    var formatIdentifier: String
    var mediaType: MediaType
    var destinationURL: URL?

    init(id: UUID = UUID(),
         url: URL,
         title: String = "",
         thumbnailURL: URL? = nil,
         createdAt: Date = .init(),
         state: DownloadState = .queued,
         formatIdentifier: String = "best",
         mediaType: MediaType = .video,
         destinationURL: URL? = nil) {
        self.id = id
        self.url = url
        self.title = title
        self.thumbnailURL = thumbnailURL
        self.createdAt = createdAt
        self.state = state
        self.formatIdentifier = formatIdentifier
        self.mediaType = mediaType
        self.destinationURL = destinationURL
    }

    static func == (lhs: DownloadTask, rhs: DownloadTask) -> Bool {
        lhs.id == rhs.id
    }
}
