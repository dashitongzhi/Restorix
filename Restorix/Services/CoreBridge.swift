import Foundation

protocol CoreBridging: SettingsCoreBridging {
    func scan() async throws -> ScanResult
    func listRepositories() async throws -> [BackupRepository]
    func removeRepository(id: String) async throws -> Bool
    func setRepositoryEnabled(id: String, enabled: Bool) async throws -> BackupRepository
    func testRepository(id: String) async throws -> [BackupSnapshot]
    func addRepository(name: String, location: String, passwordEnvKey: String?, password: String?, expectedHostname: String, enabled: Bool) async throws -> BackupRepository
    func exportMarkdownReport(language: AppLanguage) async throws -> String
}

final class CoreBridge: CoreBridging {
    private let cliLocator: CLIExecutableLocator
    private let commandRunner: any CLICommandRunning
    private let credentialStore: any CredentialStoring
    private let scanTimeoutSeconds: TimeInterval = 600
    private let defaultCommandTimeoutSeconds: TimeInterval = 60

    init(
        cliURL: URL? = nil,
        commandRunner: any CLICommandRunning = CLICommandRunner(),
        credentialStore: any CredentialStoring = KeychainCredentialStore()
    ) {
        self.cliLocator = CLIExecutableLocator(overrideURL: cliURL)
        self.commandRunner = commandRunner
        self.credentialStore = credentialStore
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
                try credentialStore.save(password, for: passwordEnvKey)
            } catch {
                _ = try? await removeRepository(id: repository.id)
                throw error
            }
        }
        return repository
    }

    func exportMarkdownReport(language: AppLanguage = .english) async throws -> String {
        let repositories = try await listRepositories()
        let credentials = try credentials(for: repositories)
        let data = try await run(
            arguments: ["report", "markdown", "--language", language.rawValue],
            environment: credentials,
            timeout: scanTimeoutSeconds,
            accepting: [0, 2]
        )
        return String(decoding: data, as: UTF8.self)
    }

    func getConfig() async throws -> AppSettings {
        let data = try await run(arguments: ["config", "get", "--json"])
        return try JSONDecoder.restorix.decode(AppSettings.self, from: data)
    }

    func commitSettings(_ draft: SettingsDraft) async throws -> AppSettings {
        let payload = try String(
            decoding: JSONEncoder().encode(draft),
            as: UTF8.self
        )
        do {
            let data = try await run(arguments: ["config", "commit", payload])
            return try JSONDecoder.restorix.decode(AppSettings.self, from: data)
        } catch let error as CoreBridgeError where error.isUnsupportedConfigCommit {
            return try await commitSettingsUsingLegacySet(draft)
        }
    }

    private func commitSettingsUsingLegacySet(_ draft: SettingsDraft) async throws -> AppSettings {
        let executableURL = cliLocator.resolve()
        let previousData = try await run(
            arguments: ["config", "get", "--json"],
            executableURL: executableURL
        )
        let previous = try JSONDecoder.restorix.decode(AppSettings.self, from: previousData)
        let changes = legacySettingsChanges(from: previous, to: draft)
        guard !changes.isEmpty else { return previous }

        var applied: [(key: String, previousValue: String)] = []
        var lastData = previousData
        do {
            for change in changes {
                lastData = try await run(
                    arguments: ["config", "set", change.key, change.value],
                    executableURL: executableURL
                )
                applied.append((change.key, change.previousValue))
            }
        } catch {
            for rollback in applied.reversed() {
                _ = try? await run(
                    arguments: ["config", "set", rollback.key, rollback.previousValue],
                    executableURL: executableURL
                )
            }
            throw error
        }

        return try JSONDecoder.restorix.decode(AppSettings.self, from: lastData)
    }

    private func legacySettingsChanges(
        from settings: AppSettings,
        to draft: SettingsDraft
    ) -> [(key: String, value: String, previousValue: String)] {
        let candidates = [
            ("stale_hours", String(draft.staleHours), String(settings.staleHours)),
            ("loose_matching", String(draft.looseMatching), String(settings.looseMatching)),
            ("show_dock_icon", String(draft.showDockIcon), String(settings.showDockIcon)),
            ("launch_at_login", String(draft.launchAtLogin), String(settings.launchAtLogin)),
            ("notifications_enabled", String(draft.notificationsEnabled), String(settings.notificationsEnabled)),
            // Keep this last so a configured executable path cannot change the CLI used mid-transaction.
            ("cli_path", draft.cliPath, settings.cliPath)
        ]
        return candidates.filter { $0.1 != $0.2 }
    }

    private func run(
        arguments: [String],
        environment: [String: String] = [:],
        timeout: TimeInterval? = nil,
        accepting acceptedExitCodes: Set<Int32> = [0],
        executableURL: URL? = nil
    ) async throws -> Data {
        let command = arguments.joined(separator: " ")
        let result = try await commandRunner.run(
            executableURL: executableURL ?? cliLocator.resolve(),
            arguments: arguments,
            environment: environment,
            timeout: timeout ?? defaultCommandTimeoutSeconds
        )
        return try result.output(accepting: acceptedExitCodes, command: command)
    }

    private func credentials(for repositories: [BackupRepository]) throws -> [String: String] {
        var credentials: [String: String] = [:]
        for key in Set(repositories.compactMap(\.passwordEnvKey)) {
            guard let password = try credentialStore.password(for: key) else {
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
