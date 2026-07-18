import Foundation
import UserNotifications

protocol NotificationDelivering: AnyObject {
    func requestAuthorization() async throws -> Bool
    func deliver(_ plan: NotificationPlan) async throws
}

final class UserNotificationAdapter: NotificationDelivering {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func deliver(_ plan: NotificationPlan) async throws {
        let content = UNMutableNotificationContent()
        content.title = plan.title
        content.body = plan.body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "restorix-\(plan.key)",
            content: content,
            trigger: nil
        )
        try await center.add(request)
    }
}

protocol NotificationHistoryStoring: AnyObject {
    func lastSentAt(for key: String) -> Date?
    func recordSent(at date: Date, for key: String)
}

final class UserDefaultsNotificationHistory: NotificationHistoryStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func lastSentAt(for key: String) -> Date? {
        defaults.object(forKey: storageKey(key)) as? Date
    }

    func recordSent(at date: Date, for key: String) {
        defaults.set(date, forKey: storageKey(key))
    }

    private func storageKey(_ key: String) -> String {
        "notification.\(key).sentAt"
    }
}
