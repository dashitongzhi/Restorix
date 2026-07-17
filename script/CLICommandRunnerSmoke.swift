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
            timeout: 2
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
            timeout: 2
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
            timeout: 2
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
        try require(scan.summary.errorCount == 1, "bridge preserves scan summary")
        try require(scan.errors == ["docker unavailable"], "bridge accepts scan exit code 2")

        let report = try await bridge.exportMarkdownReport()
        try require(report.contains("## Errors"), "bridge accepts report exit code 2")

        let renderedEnglish = MarkdownReportRenderer.render(
            scan,
            language: .english,
            repositoryName: { $0 ?? "None" }
        )
        try require(renderedEnglish.contains("## Errors"), "English report rendering")
        try require(renderedEnglish.contains("docker unavailable"), "English report diagnostics")

        let renderedChinese = MarkdownReportRenderer.render(
            scan,
            language: .simplifiedChinese,
            repositoryName: { $0 ?? "无" }
        )
        try require(renderedChinese.contains("## 错误"), "Chinese report rendering")

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
