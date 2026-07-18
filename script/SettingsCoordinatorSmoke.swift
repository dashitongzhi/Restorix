import Foundation

@main
@MainActor
struct SettingsCoordinatorSmoke {
    static func main() async throws {
        try await verifiesRollbackWhenConfigCommitFails()
        try await verifiesLoadReconcilesSystemState()
        try await verifiesCommitPersistsActualSystemState()
        print("SettingsCoordinator smoke passed")
    }

    private static func verifiesRollbackWhenConfigCommitFails() async throws {
        let core = FakeSettingsCore(settings: settings(launchAtLogin: false))
        core.commitError = SmokeError.expectedFailure
        let system = FakeSystemPreferences(launchAtLoginEnabled: false)
        let coordinator = SettingsCoordinator(coreBridge: core, systemPreferences: system)

        var draft = SettingsDraft(settings: core.settings)
        draft.launchAtLogin = true
        do {
            _ = try await coordinator.commit(draft)
            throw SmokeError.expectationFailed("commit must fail")
        } catch SmokeError.expectedFailure {
            // Expected.
        }

        try require(system.transitions == [true, false], "launch-at-login rollback")
        try require(core.settings.launchAtLogin == false, "config remains unchanged")
    }

    private static func verifiesLoadReconcilesSystemState() async throws {
        let core = FakeSettingsCore(settings: settings(launchAtLogin: false))
        let system = FakeSystemPreferences(launchAtLoginEnabled: true)
        let coordinator = SettingsCoordinator(coreBridge: core, systemPreferences: system)

        let loaded = try await coordinator.load()

        try require(loaded.launchAtLogin, "system state wins during reconcile")
        try require(core.committedDrafts.count == 1, "reconcile uses one typed commit")
        try require(system.appliedDockIcons == [true], "dock preference applied")
    }

    private static func verifiesCommitPersistsActualSystemState() async throws {
        let core = FakeSettingsCore(settings: settings(launchAtLogin: false))
        let system = FakeSystemPreferences(launchAtLoginEnabled: false)
        system.acceptsEnable = false
        let coordinator = SettingsCoordinator(coreBridge: core, systemPreferences: system)
        var draft = SettingsDraft(settings: core.settings)
        draft.launchAtLogin = true

        let committed = try await coordinator.commit(draft)

        try require(!committed.launchAtLogin, "requires-approval state is reconciled")
        try require(core.committedDrafts.last?.launchAtLogin == false, "config stores actual system state")
    }

    private static func settings(launchAtLogin: Bool) -> AppSettings {
        AppSettings(
            staleHours: 72,
            looseMatching: false,
            showDockIcon: true,
            launchAtLogin: launchAtLogin,
            notificationsEnabled: false,
            cliPath: "",
            repositories: []
        )
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ label: String) throws {
        guard condition() else { throw SmokeError.expectationFailed(label) }
    }

    private enum SmokeError: Error {
        case expectedFailure
        case expectationFailed(String)
    }
}

@MainActor
private final class FakeSettingsCore: SettingsCoreBridging {
    var settings: AppSettings
    var committedDrafts: [SettingsDraft] = []
    var commitError: Error?

    init(settings: AppSettings) {
        self.settings = settings
    }

    func getConfig() async throws -> AppSettings {
        settings
    }

    func commitSettings(_ draft: SettingsDraft) async throws -> AppSettings {
        if let commitError { throw commitError }
        committedDrafts.append(draft)
        settings.staleHours = draft.staleHours
        settings.looseMatching = draft.looseMatching
        settings.showDockIcon = draft.showDockIcon
        settings.launchAtLogin = draft.launchAtLogin
        settings.notificationsEnabled = draft.notificationsEnabled
        settings.cliPath = draft.cliPath
        return settings
    }
}

@MainActor
private final class FakeSystemPreferences: SystemPreferencesApplying {
    var launchAtLoginEnabled: Bool
    var transitions: [Bool] = []
    var appliedDockIcons: [Bool] = []
    var acceptsEnable = true

    init(launchAtLoginEnabled: Bool) {
        self.launchAtLoginEnabled = launchAtLoginEnabled
    }

    func setLaunchAtLogin(_ enabled: Bool) throws {
        transitions.append(enabled)
        launchAtLoginEnabled = enabled && acceptsEnable
    }

    func applyDockIcon(_ showDockIcon: Bool) {
        appliedDockIcons.append(showDockIcon)
    }
}
