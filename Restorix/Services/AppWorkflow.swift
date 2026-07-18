import Foundation

struct AppScanState {
    let result: ScanResult
    let repositories: [BackupRepository]
}

struct AppMutationOutcome {
    let result: ScanResult?
    let repositories: [BackupRepository]?
    let refreshWarning: String?
}

protocol AppWorkflowing: AnyObject {
    func scan(notificationsEnabled: Bool, language: AppLanguage) async throws -> AppScanState
    func loadRepositories() async throws -> [BackupRepository]
    func addRepository(name: String, location: String, passwordEnvKey: String?, password: String?, expectedHostname: String, enabled: Bool, notificationsEnabled: Bool, language: AppLanguage) async throws -> AppMutationOutcome
    func removeRepository(id: String, notificationsEnabled: Bool, language: AppLanguage) async throws -> AppMutationOutcome
    func setRepositoryEnabled(id: String, enabled: Bool, notificationsEnabled: Bool, language: AppLanguage) async throws -> AppMutationOutcome
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
    ) async throws -> AppMutationOutcome {
        _ = try await coreBridge.addRepository(
            name: name,
            location: location,
            passwordEnvKey: passwordEnvKey,
            password: password,
            expectedHostname: expectedHostname,
            enabled: enabled
        )
        return await refreshAfterMutation(
            notificationsEnabled: notificationsEnabled,
            language: language
        )
    }

    func removeRepository(
        id: String,
        notificationsEnabled: Bool,
        language: AppLanguage
    ) async throws -> AppMutationOutcome {
        _ = try await coreBridge.removeRepository(id: id)
        return await refreshAfterMutation(
            notificationsEnabled: notificationsEnabled,
            language: language
        )
    }

    func setRepositoryEnabled(
        id: String,
        enabled: Bool,
        notificationsEnabled: Bool,
        language: AppLanguage
    ) async throws -> AppMutationOutcome {
        _ = try await coreBridge.setRepositoryEnabled(id: id, enabled: enabled)
        return await refreshAfterMutation(
            notificationsEnabled: notificationsEnabled,
            language: language
        )
    }

    func testRepository(id: String) async throws -> [BackupSnapshot] {
        try await coreBridge.testRepository(id: id)
    }

    func exportMarkdownReport(language: AppLanguage) async throws -> String {
        try await coreBridge.exportMarkdownReport(language: language)
    }

    private func refreshAfterMutation(
        notificationsEnabled: Bool,
        language: AppLanguage
    ) async -> AppMutationOutcome {
        do {
            let state = try await scan(
                notificationsEnabled: notificationsEnabled,
                language: language
            )
            return AppMutationOutcome(
                result: state.result,
                repositories: state.repositories,
                refreshWarning: nil
            )
        } catch {
            let scanMessage = error.localizedDescription
            do {
                return AppMutationOutcome(
                    result: nil,
                    repositories: try await coreBridge.listRepositories(),
                    refreshWarning: scanMessage
                )
            } catch {
                return AppMutationOutcome(
                    result: nil,
                    repositories: nil,
                    refreshWarning: "\(scanMessage)\n\(error.localizedDescription)"
                )
            }
        }
    }
}
