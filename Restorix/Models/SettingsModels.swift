import Foundation

struct AppSettings: Codable {
    var staleHours: Int
    var looseMatching: Bool
    var showDockIcon: Bool
    var launchAtLogin: Bool
    var notificationsEnabled: Bool
    var cliPath: String
    var repositories: [BackupRepository]

    enum CodingKeys: String, CodingKey {
        case staleHours = "stale_hours"
        case looseMatching = "loose_matching"
        case showDockIcon = "show_dock_icon"
        case launchAtLogin = "launch_at_login"
        case notificationsEnabled = "notifications_enabled"
        case cliPath = "cli_path"
        case repositories
    }
}

struct SettingsDraft: Codable, Equatable {
    var staleHours: Int
    var looseMatching: Bool
    var showDockIcon: Bool
    var launchAtLogin: Bool
    var notificationsEnabled: Bool
    var cliPath: String

    init(
        staleHours: Int,
        looseMatching: Bool,
        showDockIcon: Bool,
        launchAtLogin: Bool,
        notificationsEnabled: Bool,
        cliPath: String
    ) {
        self.staleHours = staleHours
        self.looseMatching = looseMatching
        self.showDockIcon = showDockIcon
        self.launchAtLogin = launchAtLogin
        self.notificationsEnabled = notificationsEnabled
        self.cliPath = cliPath
    }

    init(settings: AppSettings) {
        self.init(
            staleHours: settings.staleHours,
            looseMatching: settings.looseMatching,
            showDockIcon: settings.showDockIcon,
            launchAtLogin: settings.launchAtLogin,
            notificationsEnabled: settings.notificationsEnabled,
            cliPath: settings.cliPath
        )
    }

    enum CodingKeys: String, CodingKey {
        case staleHours = "stale_hours"
        case looseMatching = "loose_matching"
        case showDockIcon = "show_dock_icon"
        case launchAtLogin = "launch_at_login"
        case notificationsEnabled = "notifications_enabled"
        case cliPath = "cli_path"
    }
}

