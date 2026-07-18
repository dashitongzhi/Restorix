import Foundation

nonisolated enum VolumeRiskPolicy {
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

nonisolated struct NotificationPlan: Equatable {
    let key: String
    let title: String
    let body: String
}

nonisolated enum NotificationPolicy {
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
