import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                Logger.general.error("Notification authorization failed: \(error.localizedDescription)")
            } else {
                Logger.general.debug("Notification authorization granted: \(granted)")
            }
        }
    }

    func postCompletionNotification(for task: DownloadTask) {
        let content = UNMutableNotificationContent()
        content.title = "다운로드 완료"
        content.body = task.title.isEmpty ? task.url.lastPathComponent : task.title
        content.sound = .default

        if case let .finished(fileURL) = task.state {
            let userInfo = ["fileURL": fileURL.path]
            content.userInfo = userInfo
        }

        let request = UNNotificationRequest(identifier: task.id.uuidString,
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Logger.general.error("Failed to post completion notification: \(error.localizedDescription)")
            }
        }
    }

    func postFailureNotification(for task: DownloadTask, reason: String) {
        let content = UNMutableNotificationContent()
        content.title = "다운로드 실패"
        content.body = reason
        content.sound = .defaultCritical

        let request = UNNotificationRequest(identifier: task.id.uuidString + ".failure",
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Logger.general.error("Failed to post failure notification: \(error.localizedDescription)")
            }
        }
    }
}
