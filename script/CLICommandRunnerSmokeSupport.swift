import Foundation

struct FixtureCredentialStore: CredentialStoring {
    func save(_: String, for _: String) throws {}

    func password(for environmentKey: String) throws -> String? {
        environmentKey == "RESTIC_PASSWORD" ? "fixture-secret" : nil
    }
}

final class ReportCredentialRunner: CLICommandRunning {
    private(set) var reportEnvironment: [String: String] = [:]

    func run(
        executableURL _: URL,
        arguments: [String],
        environment: [String: String],
        timeout _: TimeInterval
    ) async throws -> CLICommandResult {
        if arguments == ["repo", "list", "--json"] {
            let repository = BackupRepository(
                id: "repo-1",
                name: "Encrypted",
                tool: .Restic,
                location: "/tmp/repository",
                passwordEnvKey: "RESTIC_PASSWORD",
                expectedHostname: "fixture-host",
                enabled: true,
                createdAt: "2026-07-19T00:00:00Z",
                updatedAt: "2026-07-19T00:00:00Z"
            )
            return success(try JSONEncoder().encode([repository]))
        }
        if arguments.prefix(2) == ["report", "markdown"] {
            reportEnvironment = environment
            return success(Data("# Restorix Report\n".utf8))
        }
        return CLICommandResult(
            standardOutput: Data(),
            standardError: Data("unsupported fixture command".utf8),
            exitCode: 64
        )
    }

    private func success(_ data: Data) -> CLICommandResult {
        CLICommandResult(standardOutput: data, standardError: Data(), exitCode: 0)
    }
}

final class LegacySettingsRunner: CLICommandRunning {
    private var settings = AppSettings(
        staleHours: 72,
        looseMatching: false,
        showDockIcon: true,
        launchAtLogin: false,
        notificationsEnabled: false,
        cliPath: "",
        repositories: []
    )
    private(set) var setKeys: [String] = []

    func run(
        executableURL _: URL,
        arguments: [String],
        environment _: [String: String],
        timeout _: TimeInterval
    ) async throws -> CLICommandResult {
        if arguments.prefix(2) == ["config", "commit"] {
            return CLICommandResult(
                standardOutput: Data(),
                standardError: Data("error: unrecognized subcommand 'commit'".utf8),
                exitCode: 2
            )
        }
        if arguments == ["config", "get", "--json"] {
            return success(settings)
        }
        guard arguments.count == 4, arguments.prefix(2) == ["config", "set"] else {
            return CLICommandResult(
                standardOutput: Data(),
                standardError: Data("unsupported fixture command".utf8),
                exitCode: 64
            )
        }

        let key = arguments[2]
        let value = arguments[3]
        setKeys.append(key)
        switch key {
        case "stale_hours": settings.staleHours = Int(value) ?? settings.staleHours
        case "loose_matching": settings.looseMatching = value == "true"
        case "show_dock_icon": settings.showDockIcon = value == "true"
        case "launch_at_login": settings.launchAtLogin = value == "true"
        case "notifications_enabled": settings.notificationsEnabled = value == "true"
        case "cli_path": settings.cliPath = value
        default: break
        }
        return success(settings)
    }

    private func success(_ settings: AppSettings) -> CLICommandResult {
        CLICommandResult(
            standardOutput: try! JSONEncoder().encode(settings),
            standardError: Data(),
            exitCode: 0
        )
    }
}
