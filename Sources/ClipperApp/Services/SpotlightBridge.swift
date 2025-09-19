import Foundation
import AppKit

final class SpotlightBridge {
    static let notificationName = Notification.Name("com.spotlightdownloader.clipper.url")

    private let handler: (URL) -> Void
    private var observer: Any?

    init(handler: @escaping (URL) -> Void) {
        self.handler = handler
    }

    func start() {
        observer = DistributedNotificationCenter.default.addObserver(forName: Self.notificationName,
                                                                      object: nil,
                                                                      queue: .main) { [weak self] notification in
            guard let urlString = notification.userInfo?["url"] as? String,
                  let url = URL(string: urlString) else { return }
            Logger.spotlight.info("Received URL from Spotlight: \(url.absoluteString)")
            self?.handler(url)
        }
    }

    func stop() {
        if let observer {
            DistributedNotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }

    deinit {
        stop()
    }
}
