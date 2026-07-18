import Foundation
import UserNotifications

enum VolumeRiskPolicy {
    static func itemsRequiringAttention(in result: ScanResult) -> [VolumeHealth] {
        result.volumeHealth.filter { item in
            switch item.status {
            case .Unprotected, .Stale, .Unknown, .Error:
                return true
            case .Protected:
                return false
            }
        }
    }
}

struct NotificationPlan: Equatable {
    let key: String
    let title: String
    let body: String
}

enum NotificationPolicy {
    static let throttleInterval: TimeInterval = 24 * 60 * 60

    static func plan(
        for result: ScanResult,
        enabled: Bool,
        language: AppLanguage,
        lastSentAt: Date?,
        now: Date
    ) -> NotificationPlan? {
        guard enabled else { return nil }
        let risky = VolumeRiskPolicy.itemsRequiringAttention(in: result)
        guard !risky.isEmpty else { return nil }
        if let lastSentAt, now.timeIntervalSince(lastSentAt) < throttleInterval {
            return nil
        }

        return NotificationPlan(
            key: notificationKey(for: risky),
            title: language == .simplifiedChinese ? "Restorix 提醒" : "Restorix Alert",
            body: body(for: risky, language: language)
        )
    }

    static func notificationKey(for items: [VolumeHealth]) -> String {
        items
            .map { "\($0.volume.name)-\($0.status.rawValue)" }
            .sorted()
            .joined(separator: "|")
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

final class NotificationCoordinator {
    private let delivery: any NotificationDelivering
    private let history: any NotificationHistoryStoring
    private let now: () -> Date

    init(
        delivery: any NotificationDelivering = UserNotificationAdapter(),
        history: any NotificationHistoryStoring = UserDefaultsNotificationHistory(),
        now: @escaping () -> Date = Date.init
    ) {
        self.delivery = delivery
        self.history = history
        self.now = now
    }

    func notifyIfNeeded(for result: ScanResult, enabled: Bool, language: AppLanguage) async throws {
        let risky = VolumeRiskPolicy.itemsRequiringAttention(in: result)
        let key = NotificationPolicy.notificationKey(for: risky)
        let currentDate = now()
        guard let plan = NotificationPolicy.plan(
            for: result,
            enabled: enabled,
            language: language,
            lastSentAt: history.lastSentAt(for: key),
            now: currentDate
        ) else {
            return
        }

        guard try await delivery.requestAuthorization() else { return }
        try await delivery.deliver(plan)
        history.recordSent(at: currentDate, for: plan.key)
    }
}
