import Foundation

final class CoreBridge {
    private let cliURLOverride: URL?
    private let commandTimeoutSeconds: TimeInterval = 180

    init(cliURL: URL? = nil) {
        self.cliURLOverride = cliURL
    }

    func scan() async throws -> ScanResult {
        let data = try await run(arguments: ["scan", "--json"])
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
        let data = try await run(arguments: ["repo", "test", id, "--json"])
        return try JSONDecoder.restorix.decode([BackupSnapshot].self, from: data)
    }

    func addRepository(name: String, location: String, passwordEnvKey: String?, enabled: Bool) async throws -> BackupRepository {
        var arguments = [
            "repo", "add",
            "--tool", "restic",
            "--name", name,
            "--location", location,
            "--enabled", enabled ? "true" : "false"
        ]

        if let passwordEnvKey, !passwordEnvKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments.append(contentsOf: ["--password-env-key", passwordEnvKey])
        }

        let data = try await run(arguments: arguments)
        return try JSONDecoder.restorix.decode(BackupRepository.self, from: data)
    }

    func exportMarkdownReport(language: AppLanguage = .english) async throws -> String {
        let data = try await run(arguments: ["report", "markdown", "--language", language.rawValue])
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

    private func run(arguments: [String]) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()
            let cliURL = resolveCLIURL()
            let commandTimeoutSeconds = self.commandTimeoutSeconds

            process.executableURL = cliURL
            process.arguments = arguments
            process.standardOutput = stdout
            process.standardError = stderr
            process.environment = ProcessInfo.processInfo.environment.merging([
                "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            ]) { current, _ in current }

            let state = ProcessRunState()
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
            timer.schedule(deadline: .now() + commandTimeoutSeconds)
            timer.setEventHandler {
                guard process.isRunning else { return }
                process.terminate()
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                    if process.isRunning {
                        process.interrupt()
                    }
                }
                state.finish {
                    continuation.resume(
                        throwing: CoreBridgeError.commandTimedOut(arguments.joined(separator: " "), Int(commandTimeoutSeconds))
                    )
                }
            }
            timer.resume()

            process.terminationHandler = { process in
                timer.cancel()
                let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
                let errorData = stderr.fileHandleForReading.readDataToEndOfFile()

                if process.terminationStatus == 0 {
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

    private static func defaultCLIURL() -> URL {
        if let configured = configuredCLIURL() {
            return configured
        }

        if let bundled = Bundle.main.url(forResource: "restorix", withExtension: nil) {
            return bundled
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

    private static func configURL() -> URL? {
        if let override = ProcessInfo.processInfo.environment["RESTORIX_CONFIG"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }

        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Restorix", isDirectory: true)
            .appendingPathComponent("config.json")
    }
}

enum CoreBridgeError: LocalizedError {
    case commandFailed(String)
    case commandTimedOut(String, Int)
    case launchFailed(String, String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Restorix command failed." : message
        case .commandTimedOut(let command, let seconds):
            return "Restorix command timed out after \(seconds)s: \(command)"
        case .launchFailed(let path, let message):
            return "Restorix could not launch the CLI at \(path). \(message)"
        }
    }
}

private final class ProcessRunState: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe)
    private var finished = false

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

extension JSONDecoder {
    static var restorix: JSONDecoder {
        JSONDecoder()
    }
}

private struct RemoveRepositoryResult: Codable {
    let removed: Bool
}
