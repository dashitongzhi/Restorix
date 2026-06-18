import Foundation
import ServiceManagement

@MainActor
enum LaunchAtLoginReleaseVerifier {
    static let environmentKey = "RESTORIX_RELEASE_VERIFY_LAUNCH_AT_LOGIN"

    static func requestedAction(from environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        guard let rawAction = environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawAction.isEmpty else {
            return nil
        }

        return rawAction
    }

    static func run(action: String, appViewModel: AppViewModel) async -> Int32 {
        do {
            let expectedEnabled: Bool

            switch action {
            case "enable":
                try await setLaunchAtLogin(true, appViewModel: appViewModel)
                expectedEnabled = true
            case "confirm-enabled":
                try await loadConfig(appViewModel)
                expectedEnabled = true
            case "disable":
                try await setLaunchAtLogin(false, appViewModel: appViewModel)
                expectedEnabled = false
            default:
                throw VerificationError.unsupportedAction(action)
            }

            try await assertLaunchAtLogin(expectedEnabled, appViewModel: appViewModel, action: action)
            return 0
        } catch {
            log("failed action=\(action) error=\(error.localizedDescription)", error: true)
            return 1
        }
    }

    private static func setLaunchAtLogin(_ enabled: Bool, appViewModel: AppViewModel) async throws {
        try appViewModel.applyLaunchAtLoginPreference(enabled)
        try await loadConfig(appViewModel)
    }

    private static func loadConfig(_ appViewModel: AppViewModel) async throws {
        appViewModel.lastError = nil
        await appViewModel.loadConfig()

        if let lastError = appViewModel.lastError,
           !lastError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw VerificationError.appError(lastError)
        }

        guard appViewModel.settings != nil else {
            throw VerificationError.missingSettings
        }
    }

    private static func assertLaunchAtLogin(
        _ expectedEnabled: Bool,
        appViewModel: AppViewModel,
        action: String
    ) async throws {
        try await loadConfig(appViewModel)

        let serviceStatus = SMAppService.mainApp.status
        let systemEnabled = serviceStatus == .enabled
        let configEnabled = appViewModel.settings?.launchAtLogin == true

        log(
            "action=\(action) system_status=\(statusDescription(serviceStatus)) system_enabled=\(systemEnabled) config_launch_at_login=\(configEnabled)"
        )

        guard systemEnabled == expectedEnabled else {
            throw VerificationError.systemMismatch(
                expected: expectedEnabled,
                actual: statusDescription(serviceStatus)
            )
        }

        guard configEnabled == expectedEnabled else {
            throw VerificationError.configMismatch(expected: expectedEnabled, actual: configEnabled)
        }
    }

    private static func statusDescription(_ status: SMAppService.Status) -> String {
        switch status {
        case .notRegistered:
            return "notRegistered"
        case .enabled:
            return "enabled"
        case .requiresApproval:
            return "requiresApproval"
        case .notFound:
            return "notFound"
        @unknown default:
            return "unknown"
        }
    }

    private static func log(_ message: String, error: Bool = false) {
        let line = "[restorix-launch-login] \(message)\n"
        if error {
            FileHandle.standardError.write(Data(line.utf8))
        } else {
            FileHandle.standardOutput.write(Data(line.utf8))
        }
    }

    private enum VerificationError: LocalizedError {
        case unsupportedAction(String)
        case appError(String)
        case missingSettings
        case systemMismatch(expected: Bool, actual: String)
        case configMismatch(expected: Bool, actual: Bool)

        var errorDescription: String? {
            switch self {
            case .unsupportedAction(let action):
                return "Unsupported launch-at-login verification action: \(action)."
            case .appError(let message):
                return message
            case .missingSettings:
                return "Restorix settings did not load."
            case .systemMismatch(let expected, let actual):
                return "Expected macOS login item enabled=\(expected), but SMAppService status was \(actual)."
            case .configMismatch(let expected, let actual):
                return "Expected launch_at_login=\(expected), but config reported \(actual)."
            }
        }
    }
}
