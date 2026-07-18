import Foundation

@main
struct AppWorkflowSmoke {
    static func main() async throws {
        let core = FakeWorkflowCore()
        let workflow = AppWorkflow(
            coreBridge: core,
            notificationCoordinator: NotificationCoordinator(
                delivery: FakeNotificationDelivery(),
                history: FakeNotificationHistory()
            )
        )

        let outcome = try await workflow.addRepository(
            name: "Local",
            location: "/tmp/repository",
            passwordEnvKey: nil,
            password: nil,
            expectedHostname: "fixture-host",
            enabled: true,
            notificationsEnabled: false,
            language: .english
        )

        try require(core.addCount == 1, "repository mutation runs once")
        try require(outcome.result == nil, "failed scan does not replace the prior scan")
        try require(outcome.repositories?.map(\.name) == ["Local"], "repositories refresh after mutation")
        try require(outcome.refreshWarning?.contains("fixture scan failed") == true, "scan failure is a warning")

        print("AppWorkflow smoke passed")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ label: String) throws {
        guard condition() else { throw SmokeError.expectationFailed(label) }
    }

    private enum SmokeError: LocalizedError {
        case expectationFailed(String)

        var errorDescription: String? {
            guard case .expectationFailed(let label) = self else { return nil }
            return "Smoke expectation failed: \(label)"
        }
    }
}

private final class FakeNotificationDelivery: NotificationDelivering {
    func requestAuthorization() async throws -> Bool { true }
    func deliver(_: NotificationPlan) async throws {}
}

private final class FakeNotificationHistory: NotificationHistoryStoring {
    func lastSentAt(for _: String) -> Date? { nil }
    func recordSent(at _: Date, for _: String) {}
}

private final class FakeWorkflowCore: CoreBridging {
    private(set) var addCount = 0
    private var repositories: [BackupRepository] = []

    func scan() async throws -> ScanResult {
        throw FixtureError.scanFailed
    }

    func listRepositories() async throws -> [BackupRepository] {
        repositories
    }

    func addRepository(
        name: String,
        location: String,
        passwordEnvKey: String?,
        password _: String?,
        expectedHostname: String,
        enabled: Bool
    ) async throws -> BackupRepository {
        addCount += 1
        let repository = BackupRepository(
            id: "repo-1",
            name: name,
            tool: .Restic,
            location: location,
            passwordEnvKey: passwordEnvKey,
            expectedHostname: expectedHostname,
            enabled: enabled,
            createdAt: "2026-07-19T00:00:00Z",
            updatedAt: "2026-07-19T00:00:00Z"
        )
        repositories = [repository]
        return repository
    }

    func removeRepository(id _: String) async throws -> Bool { true }

    func setRepositoryEnabled(id _: String, enabled _: Bool) async throws -> BackupRepository {
        repositories[0]
    }

    func testRepository(id _: String) async throws -> [BackupSnapshot] { [] }

    func exportMarkdownReport(language _: AppLanguage) async throws -> String { "" }

    func getConfig() async throws -> AppSettings {
        AppSettings(
            staleHours: 72,
            looseMatching: false,
            showDockIcon: true,
            launchAtLogin: false,
            notificationsEnabled: false,
            cliPath: "",
            repositories: repositories
        )
    }

    func commitSettings(_ draft: SettingsDraft) async throws -> AppSettings {
        AppSettings(
            staleHours: draft.staleHours,
            looseMatching: draft.looseMatching,
            showDockIcon: draft.showDockIcon,
            launchAtLogin: draft.launchAtLogin,
            notificationsEnabled: draft.notificationsEnabled,
            cliPath: draft.cliPath,
            repositories: repositories
        )
    }

    private enum FixtureError: LocalizedError {
        case scanFailed

        var errorDescription: String? { "fixture scan failed" }
    }
}
