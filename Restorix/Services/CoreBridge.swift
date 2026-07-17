import Foundation

final class CoreBridge {
    private let cliLocator: CLIExecutableLocator
    private let commandRunner: any CLICommandRunning
    private let scanTimeoutSeconds: TimeInterval = 600
    private let defaultCommandTimeoutSeconds: TimeInterval = 60

    init(
        cliURL: URL? = nil,
        commandRunner: any CLICommandRunning = CLICommandRunner()
    ) {
        self.cliLocator = CLIExecutableLocator(overrideURL: cliURL)
        self.commandRunner = commandRunner
    }

    func resolvedCLIURLForVerification() -> URL {
        cliLocator.resolve()
    }

    func scan() async throws -> ScanResult {
        let repositories = try await listRepositories()
        let credentials = try credentials(for: repositories)
        let data = try await run(
            arguments: ["scan", "--json"],
            environment: credentials,
            timeout: scanTimeoutSeconds,
            accepting: [0, 2]
        )
        return try JSONDecoder.restorix.decode(ScanResult.self, from: data)
    }

    func listRepositories() async throws -> [BackupRepository] {
        let data = try await run(arguments: ["repo", "list", "--json"])
        return try JSONDecoder.restorix.decode([BackupRepository].self, from: data)
    }

    func removeRepository(id: String) async throws -> Bool {
        let data = try await run(arguments: ["repo", "remove", id])
        let result = try JSONDecoder.restorix.decode(RemoveRepositoryResult.self, from: data)
        return result.removed
    }

    func setRepositoryEnabled(id: String, enabled: Bool) async throws -> BackupRepository {
        let command = enabled ? "enable" : "disable"
        let data = try await run(arguments: ["repo", command, id])
        return try JSONDecoder.restorix.decode(BackupRepository.self, from: data)
    }

    func testRepository(id: String) async throws -> [BackupSnapshot] {
        let repositories = try await listRepositories()
        let credentials = try credentials(for: repositories.filter { $0.id == id })
        let data = try await run(arguments: ["repo", "test", id, "--json"], environment: credentials)
        return try JSONDecoder.restorix.decode([BackupSnapshot].self, from: data)
    }

    func addRepository(name: String, location: String, passwordEnvKey: String?, password: String?, expectedHostname: String, enabled: Bool) async throws -> BackupRepository {
        var arguments = [
            "repo", "add",
            "--tool", "restic",
            "--name", name,
            "--location", location,
            "--expected-hostname", expectedHostname,
            "--enabled", enabled ? "true" : "false"
        ]

        if let passwordEnvKey, !passwordEnvKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments.append(contentsOf: ["--password-env-key", passwordEnvKey])
        }

        let data = try await run(arguments: arguments)
        let repository = try JSONDecoder.restorix.decode(BackupRepository.self, from: data)
        if let password, let passwordEnvKey, !password.isEmpty {
            do {
                try KeychainCredentialStore.save(password, for: passwordEnvKey)
            } catch {
                _ = try? await removeRepository(id: repository.id)
                throw error
            }
        }
        return repository
    }

    func exportMarkdownReport(language: AppLanguage = .english) async throws -> String {
        let data = try await run(
            arguments: ["report", "markdown", "--language", language.rawValue],
            timeout: scanTimeoutSeconds,
            accepting: [0, 2]
        )
        return String(decoding: data, as: UTF8.self)
    }

    func getConfig() async throws -> AppSettings {
        let data = try await run(arguments: ["config", "get", "--json"])
        return try JSONDecoder.restorix.decode(AppSettings.self, from: data)
    }

    func setConfig(key: String, value: String) async throws -> AppSettings {
        let data = try await run(arguments: ["config", "set", key, value])
        return try JSONDecoder.restorix.decode(AppSettings.self, from: data)
    }

    private func run(
        arguments: [String],
        environment: [String: String] = [:],
        timeout: TimeInterval? = nil,
        accepting acceptedExitCodes: Set<Int32> = [0]
    ) async throws -> Data {
        let command = arguments.joined(separator: " ")
        let result = try await commandRunner.run(
            executableURL: cliLocator.resolve(),
            arguments: arguments,
            environment: environment,
            timeout: timeout ?? defaultCommandTimeoutSeconds
        )
        return try result.output(accepting: acceptedExitCodes, command: command)
    }

    private func credentials(for repositories: [BackupRepository]) throws -> [String: String] {
        var credentials: [String: String] = [:]
        for key in Set(repositories.compactMap(\.passwordEnvKey)) {
            guard let password = try KeychainCredentialStore.password(for: key) else {
                throw CoreBridgeError.missingKeychainCredential(key)
            }
            credentials[key] = password
        }
        return credentials
    }

}

extension JSONDecoder {
    static var restorix: JSONDecoder {
        JSONDecoder()
    }
}

private struct RemoveRepositoryResult: Codable {
    let removed: Bool
}
