import Foundation

enum Logger {
    static let subsystem = "com.spotlightdownloader.clipper"

    static let general = LogCategory(name: "general")
    static let download = LogCategory(name: "download")
    static let spotlight = LogCategory(name: "spotlight")

    struct LogCategory {
        let name: String

        func info(_ message: String) {
            #if DEBUG
            print("[INFO][\(Logger.subsystem).\(name)] \(message)")
            #endif
        }

        func error(_ message: String) {
            print("[ERROR][\(Logger.subsystem).\(name)] \(message)")
        }

        func debug(_ message: String) {
            #if DEBUG
            print("[DEBUG][\(Logger.subsystem).\(name)] \(message)")
            #endif
        }
    }
}
