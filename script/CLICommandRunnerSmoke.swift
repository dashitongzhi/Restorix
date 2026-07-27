import Foundation

@main
struct CLICommandRunnerSmoke {
    static func main() async throws {
        guard CommandLine.arguments.count == 3 else {
            throw SmokeError.missingFixture
        }

        let fixtureURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let rustContractURL = URL(fileURLWithPath: CommandLine.arguments[2])
        let runner = CLICommandRunner(baseEnvironment: [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"
        ])

        let rustContract = try JSONDecoder.restorix.decode(
            ScanResult.self,
            from: Data(contentsOf: rustContractURL)
        )
        try require(rustContract.schemaVersion == 1, "Rust contract schema version")
        try require(rustContract.summary.platform == .MacOS, "Rust contract platform")
        try require(rustContract.volumeHealth.first?.status == .Protected, "Rust contract health status")
        try require(rustContract.volumeHealth.first?.reason.code == .recentSnapshot, "Rust contract diagnostic")

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
        try require(scan.schemaVersion == 1, "current scan schema version")
        try require(scan.summary.errorCount == 2, "bridge preserves scan summary")
        try require(scan.errors.map(\.message) == ["docker unavailable"], "bridge accepts scan exit code 2")
        try require(scan.volumeHealth.first?.reason.message == "current volume error", "current diagnostic object")

        var legacyScanObject = try requireDictionary(JSONSerialization.jsonObject(with: JSONEncoder().encode(scan)))
        legacyScanObject.removeValue(forKey: "schema_version")
        let legacyScanData = try JSONSerialization.data(withJSONObject: legacyScanObject)
        let legacyScan = try JSONDecoder.restorix.decode(ScanResult.self, from: legacyScanData)
        try require(legacyScan.schemaVersion == 1, "missing scan schema defaults to version 1")

        legacyScanObject["schema_version"] = 7
        let versionedScanData = try JSONSerialization.data(withJSONObject: legacyScanObject)
        let versionedScan = try JSONDecoder.restorix.decode(ScanResult.self, from: versionedScanData)
        try require(versionedScan.schemaVersion == 7, "explicit scan schema version")

        let futureHealth = try JSONDecoder().decode(
            HealthStatus.self,
            from: Data(#""FutureStatus""#.utf8)
        )
        try require(futureHealth == .Unknown, "future health status fallback")
        let futureConfidence = try JSONDecoder().decode(
            MatchConfidence.self,
            from: Data(#""FutureConfidence""#.utf8)
        )
        try require(futureConfidence == .None, "future match confidence fallback")
        let futurePlatform = try JSONDecoder().decode(
            Platform.self,
            from: Data(#""FuturePlatform""#.utf8)
        )
        try require(futurePlatform == .Unknown, "future platform fallback")
        let futureTool = try JSONDecoder().decode(
            BackupTool.self,
            from: Data(#""FutureTool""#.utf8)
        )
        try require(futureTool == .Unknown, "future backup tool fallback")

        let report = try await bridge.exportMarkdownReport()
        try require(report.contains("## Errors"), "bridge accepts report exit code 2")

        let reportRunner = ReportCredentialRunner()
        let credentialStore = FixtureCredentialStore()
        let credentialBridge = CoreBridge(
            cliURL: fixtureURL,
            commandRunner: reportRunner,
            credentialStore: credentialStore
        )
        _ = try await credentialBridge.scan()
        _ = try await credentialBridge.exportMarkdownReport()
        try require(
            reportRunner.scanEnvironment["RESTIC_PASSWORD"] == "fixture-secret",
            "scan receives enabled repository credentials"
        )
        try require(
            reportRunner.reportEnvironment["RESTIC_PASSWORD"] == "fixture-secret",
            "report receives repository credentials"
        )
        try require(
            reportRunner.scanEnvironment["DISABLED_PASSWORD"] == nil
                && reportRunner.reportEnvironment["DISABLED_PASSWORD"] == nil,
            "disabled repository credential is not forwarded"
        )
        try require(
            !credentialStore.requestedKeys.contains("DISABLED_PASSWORD"),
            "disabled repository credential is not read"
        )

        do {
            _ = try await CoreBridge(
                cliURL: fixtureURL,
                commandRunner: InvalidScanRunner()
            ).scan()
            throw SmokeError.expectationFailed("invalid scan response must throw")
        } catch CoreBridgeError.invalidResponse(_, let path, let reason) {
            try require(path.contains("summary") && path.contains("scanned_at"), "decoding error coding path")
            try require(reason.contains("No value associated with key"), "decoding error reason")
        }

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

    private static func requireDictionary(_ value: Any) throws -> [String: Any] {
        guard let dictionary = value as? [String: Any] else {
            throw SmokeError.expectationFailed("scan JSON dictionary")
        }
        return dictionary
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
