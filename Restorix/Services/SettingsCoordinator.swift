import AppKit
import ServiceManagement

@MainActor
protocol SystemPreferencesApplying: AnyObject {
    var launchAtLoginEnabled: Bool { get }
    func setLaunchAtLogin(_ enabled: Bool) throws
    func applyDockIcon(_ showDockIcon: Bool)
}

@MainActor
final class MacSystemPreferencesAdapter: SystemPreferencesApplying {
    var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            if service.status != .enabled {
                try service.register()
            }
        } else if service.status == .enabled || service.status == .requiresApproval {
            try service.unregister()
        }
    }

    func applyDockIcon(_ showDockIcon: Bool) {
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
        if showDockIcon {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

@MainActor
final class SettingsCoordinator {
    private let coreBridge: any SettingsCoreBridging
    private let systemPreferences: any SystemPreferencesApplying

    init(
        coreBridge: any SettingsCoreBridging,
        systemPreferences: (any SystemPreferencesApplying)? = nil
    ) {
        self.coreBridge = coreBridge
        self.systemPreferences = systemPreferences ?? MacSystemPreferencesAdapter()
    }

    func load() async throws -> AppSettings {
        var settings = try await coreBridge.getConfig()
        let systemLaunchAtLogin = systemPreferences.launchAtLoginEnabled
        if settings.launchAtLogin != systemLaunchAtLogin {
            settings.launchAtLogin = systemLaunchAtLogin
            settings = try await coreBridge.commitSettings(SettingsDraft(settings: settings))
        }
        systemPreferences.applyDockIcon(settings.showDockIcon)
        return settings
    }

    func commit(_ draft: SettingsDraft) async throws -> AppSettings {
        let previousLaunchAtLogin = systemPreferences.launchAtLoginEnabled
        let changedLaunchAtLogin = previousLaunchAtLogin != draft.launchAtLogin

        if changedLaunchAtLogin {
            try systemPreferences.setLaunchAtLogin(draft.launchAtLogin)
        }

        do {
            let settings = try await coreBridge.commitSettings(draft)
            systemPreferences.applyDockIcon(settings.showDockIcon)
            return settings
        } catch {
            if changedLaunchAtLogin {
                try? systemPreferences.setLaunchAtLogin(previousLaunchAtLogin)
            }
            throw error
        }
    }
}
