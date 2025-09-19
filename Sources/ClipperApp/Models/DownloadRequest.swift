import Foundation

struct DownloadRequest {
    enum Source {
        case spotlight
        case manual
    }

    let url: URL
    var format: String
    var mediaType: DownloadTask.MediaType
    var customTitle: String?
    var source: Source

    init(url: URL,
         format: String,
         mediaType: DownloadTask.MediaType = .video,
         customTitle: String? = nil,
         source: Source = .manual) {
        self.url = url
        self.format = format
        self.mediaType = mediaType
        self.customTitle = customTitle
        self.source = source
    }
}
