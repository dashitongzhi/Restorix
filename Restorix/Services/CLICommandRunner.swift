import Darwin
import Foundation

protocol CLICommandRunning {
    func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        timeout: TimeInterval
    ) async throws -> CLICommandResult
}

struct CLICommandResult {
    let standardOutput: Data
    let standardError: Data
    let exitCode: Int32

    func output(accepting acceptedExitCodes: Set<Int32>, command: String) throws -> Data {
        guard acceptedExitCodes.contains(exitCode) else {
            throw CoreBridgeError.commandFailed(
                command: command,
                exitCode: exitCode,
                message: String(decoding: standardError, as: UTF8.self)
            )
        }
        return standardOutput
    }
}

final class CLICommandRunner: CLICommandRunning {
    private let baseEnvironment: [String: String]

    init(baseEnvironment: [String: String] = ProcessInfo.processInfo.environment) {
        self.baseEnvironment = baseEnvironment
    }

    func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String] = [:],
        timeout: TimeInterval
    ) async throws -> CLICommandResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()
            let command = arguments.joined(separator: " ")

            process.executableURL = executableURL
            process.arguments = arguments
            process.standardOutput = stdout
            process.standardError = stderr
            process.environment = baseEnvironment.merging([
                "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            ]) { _, controlled in controlled }.merging(environment) { _, supplied in supplied }

            let state = ProcessRunState()
            let output = PipeOutputCollector(pipe: stdout)
            let errors = PipeOutputCollector(pipe: stderr)
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
            timer.schedule(deadline: .now() + timeout)
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
                            throwing: CoreBridgeError.commandTimedOut(command, Int(timeout))
                        )
                    }
                } else {
                    state.finish {
                        continuation.resume(
                            returning: CLICommandResult(
                                standardOutput: outputData,
                                standardError: errorData,
                                exitCode: process.terminationStatus
                            )
                        )
                    }
                }
            }

            do {
                try process.run()
            } catch {
                timer.cancel()
                _ = output.finish()
                _ = errors.finish()
                state.finish {
                    continuation.resume(
                        throwing: CoreBridgeError.launchFailed(
                            executableURL.path,
                            error.localizedDescription
                        )
                    )
                }
            }
        }
    }
}

enum CoreBridgeError: LocalizedError {
    case commandFailed(command: String, exitCode: Int32, message: String)
    case commandTimedOut(String, Int)
    case launchFailed(String, String)
    case missingKeychainCredential(String)
    case invalidResponse(command: String, path: String, reason: String)

    var isUnsupportedConfigCommit: Bool {
        guard case .commandFailed(let command, _, let message) = self,
              command.hasPrefix("config commit ") else {
            return false
        }
        let normalized = message.lowercased()
        return normalized.contains("unrecognized subcommand")
            || normalized.contains("unknown subcommand")
            || normalized.contains("unexpected argument 'commit'")
    }

    var errorDescription: String? {
        switch self {
        case .commandFailed(let command, let exitCode, let message):
            let details = message.trimmingCharacters(in: .whitespacesAndNewlines)
            let prefix = "Restorix command failed with exit code \(exitCode): \(command)"
            return details.isEmpty ? prefix : "\(prefix)\n\(details)"
        case .commandTimedOut(let command, let seconds):
            return "Restorix command timed out after \(seconds)s: \(command)"
        case .launchFailed(let path, let message):
            return "Restorix could not launch the CLI at \(path). \(message)"
        case .missingKeychainCredential(let key):
            return "No Keychain credential is available for \(key). Add or update the repository password in Restorix."
        case .invalidResponse(let command, let path, let reason):
            return "Restorix received an invalid response from `\(command)` at \(path): \(reason)"
        }
    }
}
