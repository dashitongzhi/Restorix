import Foundation

struct AppScanState {
    let result: ScanResult
    let repositories: [BackupRepository]
}

protocol AppWorkflowing: AnyObject {
    func scan(notificationsEnabled: Bool, language: AppLanguage) async throws -> AppScanState
    func loadRepositories() async throws -> [BackupRepository]
    func addRepository(name: String, location: String, passwordEnvKey: String?, password: String?, expectedHostname: String, enabled: Bool, notificationsEnabled: Bool, language: AppLanguage) async throws -> AppScanState
    func removeRepository(id: String, notificationsEnabled: Bool, language: AppLanguage) async throws -> AppScanState
    func setRepositoryEnabled(id: String, enabled: Bool, notificationsEnabled: Bool, language: AppLanguage) async throws -> AppScanState
    func testRepository(id: String) async throws -> [BackupSnapshot]
    func exportMarkdownReport(language: AppLanguage) async throws -> String
}

final class AppWorkflow: AppWorkflowing {
    private let coreBridge: any CoreBridging
    private let notificationCoordinator: NotificationCoordinator

    init(
        coreBridge: any CoreBridging,
        notificationCoordinator: NotificationCoordinator = NotificationCoordinator()
    ) {
        self.coreBridge = coreBridge
        self.notificationCoordinator = notificationCoordinator
    }

    func scan(notificationsEnabled: Bool, language: AppLanguage) async throws -> AppScanState {
        let result = try await coreBridge.scan()
        try? await notificationCoordinator.notifyIfNeeded(
            for: result,
            enabled: notificationsEnabled,
            language: language
        )
        return AppScanState(result: result, repositories: result.repositories)
    }

    func loadRepositories() async throws -> [BackupRepository] {
        try await coreBridge.listRepositories()
    }

    func addRepository(
        name: String,
        location: String,
        passwordEnvKey: String?,
        password: String?,
        expectedHostname: String,
        enabled: Bool,
        notificationsEnabled: Bool,
        language: AppLanguage
    ) async throws -> AppScanState {
        _ = try await coreBridge.addRepository(
            name: name,
            location: location,
            passwordEnvKey: passwordEnvKey,
            password: password,
            expectedHostname: expectedHostname,
            enabled: enabled
        )
        return try await scan(notificationsEnabled: notificationsEnabled, language: language)
    }

    func removeRepository(
        id: String,
        notificationsEnabled: Bool,
        language: AppLanguage
    ) async throws -> AppScanState {
        _ = try await coreBridge.removeRepository(id: id)
        return try await scan(notificationsEnabled: notificationsEnabled, language: language)
    }

    func setRepositoryEnabled(
        id: String,
        enabled: Bool,
        notificationsEnabled: Bool,
        language: AppLanguage
    ) async throws -> AppScanState {
        _ = try await coreBridge.setRepositoryEnabled(id: id, enabled: enabled)
        return try await scan(notificationsEnabled: notificationsEnabled, language: language)
    }

    func testRepository(id: String) async throws -> [BackupSnapshot] {
        try await coreBridge.testRepository(id: id)
    }

    func exportMarkdownReport(language: AppLanguage) async throws -> String {
        try await coreBridge.exportMarkdownReport(language: language)
    }
}
