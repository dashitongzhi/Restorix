import Foundation
import UserNotifications

enum NotificationService {
    static func notifyIfNeeded(for result: ScanResult, enabled: Bool) {
        guard enabled else { return }

        let risky = result.volumeHealth.filter { item in
            item.status == .Unprotected || item.status == .Stale || item.status == .Error
        }
        guard !risky.isEmpty else { return }

        let key = notificationKey(for: risky)
        guard shouldSendNotification(for: key) else { return }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            let language = AppLanguage(
                rawValue: UserDefaults.standard.string(forKey: "app.language") ?? AppLanguage.english.rawValue
            ) ?? .english
            let content = UNMutableNotificationContent()
            content.title = language == .simplifiedChinese ? "Restorix 提醒" : "Restorix Alert"
            content.body = body(for: risky, language: language)
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "restorix-\(key)",
                content: content,
                trigger: nil
            )

            UNUserNotificationCenter.current().add(request)
            UserDefaults.standard.set(Date(), forKey: "notification.\(key).sentAt")
        }
    }

    private static func notificationKey(for items: [VolumeHealth]) -> String {
        items
            .map { "\($0.volume.name)-\($0.status.rawValue)" }
            .sorted()
            .joined(separator: "|")
    }

    private static func shouldSendNotification(for key: String) -> Bool {
        let defaultsKey = "notification.\(key).sentAt"
        guard let lastSent = UserDefaults.standard.object(forKey: defaultsKey) as? Date else {
            return true
        }

        return Date().timeIntervalSince(lastSent) >= 24 * 60 * 60
    }

    private static func body(for items: [VolumeHealth], language: AppLanguage) -> String {
        let names = items.prefix(3).map(\.volume.name).joined(separator: ", ")
        if language == .simplifiedChinese {
            let suffix = items.count > 3 ? "，另有 \(items.count - 3) 个" : ""
            return "\(items.count) 个 Docker volume 需要关注：\(names)\(suffix)。"
        }
        let suffix = items.count > 3 ? " and \(items.count - 3) more" : ""
        return "\(items.count) Docker volume\(items.count == 1 ? " needs" : "s need") attention: \(names)\(suffix)."
    }
}
