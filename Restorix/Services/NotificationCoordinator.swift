import Foundation

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
