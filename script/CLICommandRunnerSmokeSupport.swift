import Foundation

final class FixtureCredentialStore: CredentialStoring {
    private(set) var requestedKeys: [String] = []

    func save(_: String, for _: String) throws {}

    func password(for environmentKey: String) throws -> String? {
        requestedKeys.append(environmentKey)
        return environmentKey == "RESTIC_PASSWORD" ? "fixture-secret" : nil
    }
}

final class ReportCredentialRunner: CLICommandRunning {
    private(set) var reportEnvironment: [String: String] = [:]
    private(set) var scanEnvironment: [String: String] = [:]

    func run(
        executableURL _: URL,
        arguments: [String],
        environment: [String: String],
        timeout _: TimeInterval
    ) async throws -> CLICommandResult {
        if arguments == ["repo", "list", "--json"] {
            let repositories = [
                BackupRepository(
                    id: "repo-1",
                    name: "Encrypted",
                    tool: .Restic,
                    location: "/tmp/repository",
                    passwordEnvKey: "RESTIC_PASSWORD",
                    expectedHostname: "fixture-host",
                    enabled: true,
                    createdAt: "2026-07-19T00:00:00Z",
                    updatedAt: "2026-07-19T00:00:00Z"
                ),
                BackupRepository(
                    id: "repo-disabled",
                    name: "Disabled",
                    tool: .Restic,
                    location: "/tmp/disabled",
                    passwordEnvKey: "DISABLED_PASSWORD",
                    expectedHostname: "fixture-host",
                    enabled: false,
                    createdAt: "2026-07-19T00:00:00Z",
                    updatedAt: "2026-07-19T00:00:00Z"
                )
            ]
            return success(try JSONEncoder().encode(repositories))
        }
        if arguments == ["scan", "--json"] {
            scanEnvironment = environment
            return success(Data(Self.emptyScan.utf8))
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

    private static let emptyScan = """
    {
      "schema_version": 1,
      "summary": {
        "scanned_at": "2026-07-19T00:00:00Z",
        "platform": "MacOS",
        "docker_available": true,
        "docker_running": true,
        "restic_available": true,
        "total_containers": 0,
        "total_volumes": 0,
        "protected_count": 0,
        "unprotected_count": 0,
        "stale_count": 0,
        "unknown_count": 0,
        "error_count": 0
      },
      "containers": [],
      "volumes": [],
      "repositories": [],
      "snapshots": [],
      "volume_health": [],
      "warnings": [],
      "errors": []
    }
    """
}

final class InvalidScanRunner: CLICommandRunning {
    func run(
        executableURL _: URL,
        arguments: [String],
        environment _: [String: String],
        timeout _: TimeInterval
    ) async throws -> CLICommandResult {
        let output: Data
        if arguments == ["repo", "list", "--json"] {
            output = Data("[]".utf8)
        } else if arguments == ["scan", "--json"] {
            output = Data(#"{"summary":{}}"#.utf8)
        } else {
            return CLICommandResult(
                standardOutput: Data(),
                standardError: Data("unsupported fixture command".utf8),
                exitCode: 64
            )
        }
        return CLICommandResult(standardOutput: output, standardError: Data(), exitCode: 0)
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
