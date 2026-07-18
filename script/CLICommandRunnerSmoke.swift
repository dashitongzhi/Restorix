import Foundation

@main
struct CLICommandRunnerSmoke {
    static func main() async throws {
        guard CommandLine.arguments.count == 2 else {
            throw SmokeError.missingFixture
        }

        let fixtureURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let runner = CLICommandRunner(baseEnvironment: [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"
        ])

        let success = try await runner.run(
            executableURL: fixtureURL,
            arguments: ["success"],
            environment: [:],
            timeout: 10
        )
        try require(success.exitCode == 0, "success exit code")
        let successOutput = try success.output(accepting: [0], command: "success")
        try require(
            String(decoding: successOutput, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines) == "ok",
            "success output"
        )

        let partial = try await runner.run(
            executableURL: fixtureURL,
            arguments: ["partial"],
            environment: [:],
            timeout: 10
        )
        try require(partial.exitCode == 2, "partial exit code")
        let partialOutput = try partial.output(accepting: [0, 2], command: "scan --json")
        try require(
            String(decoding: partialOutput, as: UTF8.self).contains("docker unavailable"),
            "accepted nonzero output"
        )

        do {
            _ = try partial.output(accepting: [0], command: "repo list --json")
            throw SmokeError.expectationFailed("disallowed exit code")
        } catch CoreBridgeError.commandFailed(_, let exitCode, _) {
            try require(exitCode == 2, "reported exit code")
        }

        let failure = try await runner.run(
            executableURL: fixtureURL,
            arguments: ["failure"],
            environment: [:],
            timeout: 10
        )
        do {
            _ = try failure.output(accepting: [0], command: "failure")
            throw SmokeError.expectationFailed("failure must throw")
        } catch CoreBridgeError.commandFailed(_, let exitCode, let message) {
            try require(exitCode == 3, "failure exit code")
            try require(message.contains("fixture failed"), "failure stderr")
        }

        do {
            _ = try await runner.run(
                executableURL: fixtureURL,
                arguments: ["timeout"],
                environment: [:],
                timeout: 0.1
            )
            throw SmokeError.expectationFailed("timeout must throw")
        } catch CoreBridgeError.commandTimedOut {
            // Expected.
        }

        let bridge = CoreBridge(cliURL: fixtureURL)
        let scan = try await bridge.scan()
        try require(scan.summary.errorCount == 2, "bridge preserves scan summary")
        try require(scan.errors.map(\.message) == ["docker unavailable"], "bridge accepts scan exit code 2")
        try require(scan.volumeHealth.first?.reason.message == "legacy volume error", "legacy volume reason")

        let report = try await bridge.exportMarkdownReport()
        try require(report.contains("## Errors"), "bridge accepts report exit code 2")

        let reportRunner = ReportCredentialRunner()
        let credentialBridge = CoreBridge(
            cliURL: fixtureURL,
            commandRunner: reportRunner,
            credentialStore: FixtureCredentialStore()
        )
        _ = try await credentialBridge.exportMarkdownReport()
        try require(
            reportRunner.reportEnvironment["RESTIC_PASSWORD"] == "fixture-secret",
            "report receives repository credentials"
        )

        let renderedEnglish = MarkdownReportRenderer.render(
            scan,
            language: .english,
            repositoryName: { $0 ?? "None" }
        )
        try require(renderedEnglish.contains("## Errors"), "English report rendering")
        try require(renderedEnglish.contains("docker unavailable"), "English report diagnostics")
        try require(renderedEnglish.contains("## Error Volumes"), "English error volumes rendering")
        try require(renderedEnglish.contains("broken-volume"), "English error volume row")

        let renderedChinese = MarkdownReportRenderer.render(
            scan,
            language: .simplifiedChinese,
            repositoryName: { $0 ?? "无" }
        )
        try require(renderedChinese.contains("## 错误"), "Chinese report rendering")

        let legacyDiagnostic = try JSONDecoder().decode(Diagnostic.self, from: Data(#""legacy warning""#.utf8))
        try require(legacyDiagnostic.code == .generic, "legacy string diagnostic code")
        try require(legacyDiagnostic.message == "legacy warning", "legacy string diagnostic message")

        let futureDiagnostic = try JSONDecoder().decode(
            Diagnostic.self,
            from: Data(#"{"code":"future_code","context":{},"message":"future warning"}"#.utf8)
        )
        try require(futureDiagnostic.code == .generic, "future diagnostic code fallback")
        try require(futureDiagnostic.message == "future warning", "future diagnostic message")

        let legacyRunner = LegacySettingsRunner()
        let legacyBridge = CoreBridge(cliURL: fixtureURL, commandRunner: legacyRunner)
        let legacyDraft = SettingsDraft(
            staleHours: 48,
            looseMatching: true,
            showDockIcon: false,
            launchAtLogin: true,
            notificationsEnabled: true,
            cliPath: "/opt/restorix"
        )
        let legacySettings = try await legacyBridge.commitSettings(legacyDraft)
        try require(legacySettings.staleHours == 48, "legacy settings stale hours")
        try require(legacySettings.cliPath == "/opt/restorix", "legacy settings cli path")
        try require(legacyRunner.setKeys.last == "cli_path", "legacy cli path applied last")

        print("CLICommandRunner smoke passed")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ label: String) throws {
        guard condition() else {
            throw SmokeError.expectationFailed(label)
        }
    }

    private enum SmokeError: LocalizedError {
        case missingFixture
        case expectationFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingFixture:
                return "Expected the fixture executable path."
            case .expectationFailed(let label):
                return "Smoke expectation failed: \(label)"
            }
        }
    }
}

private struct FixtureCredentialStore: CredentialStoring {
    func save(_: String, for _: String) throws {}
    func password(for environmentKey: String) throws -> String? {
        environmentKey == "RESTIC_PASSWORD" ? "fixture-secret" : nil
    }
}

private final class ReportCredentialRunner: CLICommandRunning {
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

private final class LegacySettingsRunner: CLICommandRunning {
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
