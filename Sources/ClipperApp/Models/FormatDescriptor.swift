import Foundation

struct FormatDescriptor: Identifiable, Equatable {
    let id: String
    let description: String
    let fileExtension: String
    let resolution: String
    let note: String

    init(id: String, description: String, fileExtension: String, resolution: String, note: String) {
        self.id = id
        self.description = description
        self.fileExtension = fileExtension
        self.resolution = resolution
        self.note = note
    }
}
