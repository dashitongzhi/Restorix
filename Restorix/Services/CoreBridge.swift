import Foundation
import Darwin

final class CoreBridge {
    private let cliURLOverride: URL?
    private let scanTimeoutSeconds: TimeInterval = 600
    private let defaultCommandTimeoutSeconds: TimeInterval = 60

    init(cliURL: URL? = nil) {
        self.cliURLOverride = cliURL
    }

    func resolvedCLIURLForVerification() -> URL {
        resolveCLIURL()
    }

    func scan() async throws -> ScanResult {
        let credentials = try await credentials(for: listRepositories())
        let data = try await run(arguments: ["scan", "--json"], environment: credentials, timeout: scanTimeoutSeconds)
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
        let credentials = try await credentials(for: repositories.filter { $0.id == id })
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
            timeout: scanTimeoutSeconds
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

    private func run(arguments: [String], environment: [String: String] = [:], timeout: TimeInterval? = nil) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()
            let cliURL = resolveCLIURL()
            let commandTimeoutSeconds = timeout ?? defaultCommandTimeoutSeconds

            process.executableURL = cliURL
            process.arguments = arguments
            process.standardOutput = stdout
            process.standardError = stderr
            process.environment = ProcessInfo.processInfo.environment.merging([
                "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            ]) { _, controlled in controlled }.merging(environment) { _, credential in credential }

            let state = ProcessRunState()
            let output = PipeOutputCollector(pipe: stdout)
            let errors = PipeOutputCollector(pipe: stderr)
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
            timer.schedule(deadline: .now() + commandTimeoutSeconds)
            timer.setEventHandler {
                guard process.isRunning else { return }
                state.markTimedOut()
                process.terminate()
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                    if process.isRunning {
                        kill(process.processIdentifier, SIGKILL)
                    }
                }
            }
            timer.resume()

            process.terminationHandler = { process in
                timer.cancel()
                let outputData = output.finish()
                let errorData = errors.finish()

                if state.didTimeOut {
                    state.finish {
                        continuation.resume(
                            throwing: CoreBridgeError.commandTimedOut(arguments.joined(separator: " "), Int(commandTimeoutSeconds))
                        )
                    }
                } else if process.terminationStatus == 0 {
                    state.finish {
                        continuation.resume(returning: outputData)
                    }
                } else {
                    let errorText = String(decoding: errorData, as: UTF8.self)
                    state.finish {
                        continuation.resume(throwing: CoreBridgeError.commandFailed(errorText))
                    }
                }
            }

            do {
                try process.run()
            } catch {
                timer.cancel()
                output.finish()
                errors.finish()
                state.finish {
                    continuation.resume(throwing: CoreBridgeError.launchFailed(cliURL.path, error.localizedDescription))
                }
            }
        }
    }

    private func resolveCLIURL() -> URL {
        if let cliURLOverride {
            return cliURLOverride
        }

        return Self.defaultCLIURL()
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

    private static func defaultCLIURL() -> URL {
        if let configured = configuredCLIURL() {
            if shouldStageAppBundleResource(configured),
               let staged = stageBundledCLI(from: configured) {
                return staged
            }
            return configured
        }

        if let bundled = Bundle.main.url(forResource: "restorix", withExtension: nil),
           let staged = stageBundledCLI(from: bundled) {
            return staged
        }

        let candidates = [
            "/usr/local/bin/restorix",
            "/opt/homebrew/bin/restorix",
            FileManager.default.currentDirectoryPath + "/target/debug/restorix"
        ]

        if let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return URL(fileURLWithPath: path)
        }

        return URL(fileURLWithPath: "/usr/local/bin/restorix")
    }

    private static func configuredCLIURL() -> URL? {
        guard let configURL = configURL(),
              let data = try? Data(contentsOf: configURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let path = object["cli_path"] as? String else {
            return nil
        }

        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, FileManager.default.isExecutableFile(atPath: trimmed) else {
            return nil
        }

        return URL(fileURLWithPath: trimmed)
    }

    private static func shouldStageAppBundleResource(_ url: URL) -> Bool {
        let components = url.standardizedFileURL.pathComponents
        guard url.lastPathComponent == "restorix",
              let contentsIndex = components.lastIndex(of: "Contents"),
              contentsIndex + 1 < components.count else {
            return false
        }

        return components[contentsIndex + 1] == "Resources"
    }

    private static func configURL() -> URL? {
        if let override = ProcessInfo.processInfo.environment["RESTORIX_CONFIG"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }

        return applicationSupportDirectoryURL()?.appendingPathComponent("config.json")
    }

    private static func stageBundledCLI(from bundledURL: URL) -> URL? {
        let fileManager = FileManager.default
        guard let binDirectory = applicationSupportDirectoryURL()?.appendingPathComponent("bin", isDirectory: true) else {
            return nil
        }

        let stagedURL = binDirectory.appendingPathComponent("restorix")

        do {
            try fileManager.createDirectory(at: binDirectory, withIntermediateDirectories: true)
            if shouldStageBundledCLI(from: bundledURL, to: stagedURL) {
                if fileManager.fileExists(atPath: stagedURL.path) {
                    try fileManager.removeItem(at: stagedURL)
                }
                try fileManager.copyItem(at: bundledURL, to: stagedURL)
                try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: stagedURL.path)
            }
            return fileManager.isExecutableFile(atPath: stagedURL.path) ? stagedURL : nil
        } catch {
            return nil
        }
    }

    private static func shouldStageBundledCLI(from bundledURL: URL, to stagedURL: URL) -> Bool {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: stagedURL.path) else {
            return true
        }

        let bundledAttributes = try? fileManager.attributesOfItem(atPath: bundledURL.path)
        let stagedAttributes = try? fileManager.attributesOfItem(atPath: stagedURL.path)
        let bundledSize = bundledAttributes?[.size] as? UInt64
        let stagedSize = stagedAttributes?[.size] as? UInt64
        if bundledSize != stagedSize {
            return true
        }

        guard let bundledModified = bundledAttributes?[.modificationDate] as? Date,
              let stagedModified = stagedAttributes?[.modificationDate] as? Date else {
            return !filesMatch(bundledURL, stagedURL)
        }

        return bundledModified > stagedModified || !filesMatch(bundledURL, stagedURL)
    }

    private static func filesMatch(_ leftURL: URL, _ rightURL: URL) -> Bool {
        guard let leftData = try? Data(contentsOf: leftURL),
              let rightData = try? Data(contentsOf: rightURL) else {
            return false
        }

        return leftData == rightData
    }

    private static func applicationSupportDirectoryURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Restorix", isDirectory: true)
    }
}

enum CoreBridgeError: LocalizedError {
    case commandFailed(String)
    case commandTimedOut(String, Int)
    case launchFailed(String, String)
    case missingKeychainCredential(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Restorix command failed." : message
        case .commandTimedOut(let command, let seconds):
            return "Restorix command timed out after \(seconds)s: \(command)"
        case .launchFailed(let path, let message):
            return "Restorix could not launch the CLI at \(path). \(message)"
        case .missingKeychainCredential(let key):
            return "No Keychain credential is available for \(key). Add or update the repository password in Restorix."
        }
    }
}

private final class ProcessRunState: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe)
    private var finished = false
    private var timedOut = false

    var didTimeOut: Bool {
        lock.lock()
        defer { lock.unlock() }
        return timedOut
    }

    func markTimedOut() {
        lock.lock()
        timedOut = true
        lock.unlock()
    }

    nonisolated
    func finish(_ action: () -> Void) {
        lock.lock()
        if finished {
            lock.unlock()
            return
        }
        finished = true
        lock.unlock()
        action()
    }
}

private final class PipeOutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let handle: FileHandle
    private var data = Data()
    private var isFinished = false

    init(pipe: Pipe) {
        handle = pipe.fileHandleForReading
        handle.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            self?.append(chunk)
        }
    }

    func finish() -> Data {
        lock.lock()
        guard !isFinished else {
            let result = data
            lock.unlock()
            return result
        }
        isFinished = true
        lock.unlock()

        handle.readabilityHandler = nil
        append(handle.readDataToEndOfFile())

        lock.lock()
        defer { lock.unlock() }
        return data
    }

    private func append(_ chunk: Data) {
        lock.lock()
        data.append(chunk)
        lock.unlock()
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
