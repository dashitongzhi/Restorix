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
        let credentials = try credentials(for: repositories.filter(\.enabled))
        let data = try await run(
            arguments: ["scan", "--json"],
            environment: credentials,
            timeout: scanTimeoutSeconds,
            accepting: [0, 2]
        )
        return try decode(ScanResult.self, from: data, command: "scan --json")
    }

    func listRepositories() async throws -> [BackupRepository] {
        let data = try await run(arguments: ["repo", "list", "--json"])
        return try decode([BackupRepository].self, from: data, command: "repo list --json")
    }

    func removeRepository(id: String) async throws -> Bool {
        let data = try await run(arguments: ["repo", "remove", id])
        let result = try decode(RemoveRepositoryResult.self, from: data, command: "repo remove \(id)")
        return result.removed
    }

    func setRepositoryEnabled(id: String, enabled: Bool) async throws -> BackupRepository {
        let command = enabled ? "enable" : "disable"
        let data = try await run(arguments: ["repo", command, id])
        return try decode(BackupRepository.self, from: data, command: "repo \(command) \(id)")
    }

    func testRepository(id: String) async throws -> [BackupSnapshot] {
        let repositories = try await listRepositories()
        let credentials = try credentials(for: repositories.filter { $0.id == id })
        let data = try await run(arguments: ["repo", "test", id, "--json"], environment: credentials)
        return try decode([BackupSnapshot].self, from: data, command: "repo test \(id) --json")
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
        let repository = try decode(BackupRepository.self, from: data, command: "repo add")
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
        let credentials = try credentials(for: repositories.filter(\.enabled))
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
        return try decode(AppSettings.self, from: data, command: "config get --json")
    }

    func commitSettings(_ draft: SettingsDraft) async throws -> AppSettings {
        let payload = try String(
            decoding: JSONEncoder().encode(draft),
            as: UTF8.self
        )
        do {
            let data = try await run(arguments: ["config", "commit", payload])
            return try decode(AppSettings.self, from: data, command: "config commit")
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
        let previous = try decode(AppSettings.self, from: previousData, command: "config get --json")
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

        return try decode(AppSettings.self, from: lastData, command: "config set")
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

    private func decode<Value: Decodable>(
        _ type: Value.Type,
        from data: Data,
        command: String
    ) throws -> Value {
        do {
            return try JSONDecoder.restorix.decode(type, from: data)
        } catch let error as DecodingError {
            throw CoreBridgeError.invalidResponse(
                command: command,
                path: error.restorixCodingPath,
                reason: error.restorixReason
            )
        }
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

private extension DecodingError {
    var restorixContext: DecodingError.Context {
        switch self {
        case .typeMismatch(_, let context),
             .valueNotFound(_, let context),
             .keyNotFound(_, let context),
             .dataCorrupted(let context):
            return context
        @unknown default:
            return DecodingError.Context(codingPath: [], debugDescription: String(describing: self))
        }
    }

    var restorixCodingPath: String {
        var codingPath = restorixContext.codingPath
        if case .keyNotFound(let key, _) = self {
            codingPath.append(key)
        }
        let components = codingPath.map { key in
            if let index = key.intValue {
                return "[\(index)]"
            }
            return key.stringValue
        }
        return components.isEmpty ? "<root>" : components.joined(separator: ".")
    }

    var restorixReason: String {
        let context = restorixContext
        if let underlying = context.underlyingError {
            return "\(context.debugDescription) (\(underlying.localizedDescription))"
        }
        return context.debugDescription
    }
}
