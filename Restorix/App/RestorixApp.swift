import Darwin
import Foundation
import SwiftUI

@main
struct RestorixApp: App {
    private static let releaseStatusFileKey = "RESTORIX_RELEASE_STATUS_FILE"

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @StateObject private var appViewModel: AppViewModel

    init() {
        if ProcessInfo.processInfo.environment["RESTORIX_RELEASE_VERIFY_CLI_STAGING"] == "1" {
            Self.exitForReleaseVerifier(Self.verifyCLIStaging())
        }

        let appViewModel = AppViewModel()
        _appViewModel = StateObject(wrappedValue: appViewModel)

        if let verificationAction = LaunchAtLoginReleaseVerifier.requestedAction() {
            Task { @MainActor in
                let exitCode = await LaunchAtLoginReleaseVerifier.run(
                    action: verificationAction,
                    appViewModel: appViewModel
                )
                Self.exitForReleaseVerifier(exitCode)
            }
        } else {
            Task { @MainActor in
                await appViewModel.loadConfig()
            }
        }
    }

    private static func verifyCLIStaging() -> Int32 {
        let cliURL = CoreBridge().resolvedCLIURLForVerification().standardizedFileURL
        let expectedPath = ProcessInfo.processInfo.environment["RESTORIX_RELEASE_EXPECT_STAGED_CLI"]
        let fileManager = FileManager.default

        guard fileManager.isExecutableFile(atPath: cliURL.path) else {
            fputs("[restorix-release] staged CLI is not executable: \(cliURL.path)\n", stderr)
            return 1
        }

        if let expectedPath, !expectedPath.isEmpty {
            let expectedURL = URL(fileURLWithPath: expectedPath).standardizedFileURL
            if cliURL.path != expectedURL.path {
                fputs("[restorix-release] staged CLI path mismatch: \(cliURL.path), expected \(expectedURL.path)\n", stderr)
                return 1
            }
        }

        print("[restorix-release] staged CLI: \(cliURL.path)")
        return 0
    }

    private static func exitForReleaseVerifier(_ exitCode: Int32) -> Never {
        writeReleaseStatus(exitCode)
        Darwin.exit(exitCode)
    }

    private static func writeReleaseStatus(_ exitCode: Int32) {
        guard let statusPath = ProcessInfo.processInfo.environment[releaseStatusFileKey],
              !statusPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let statusURL = URL(fileURLWithPath: statusPath)
        do {
            try FileManager.default.createDirectory(
                at: statusURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try "\(exitCode)\n".write(to: statusURL, atomically: true, encoding: .utf8)
        } catch {
            fputs("[restorix-release] failed to write status file \(statusURL.path): \(error.localizedDescription)\n", stderr)
        }
    }

    var body: some Scene {
        WindowGroup("Restorix", id: "main") {
            RootView()
                .environmentObject(appViewModel)
                .frame(minWidth: 980, minHeight: 640)
                .onAppear {
                    configureMenuBar()
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Restorix") {
                Button(appViewModel.text(.appIcon)) {
                    WindowManager.openSettings()
                }
                Button(appViewModel.text(.scanNow)) {
                    Task {
                        await appViewModel.scanNow()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appViewModel)
                .frame(width: 640, height: 660)
                .onAppear {
                    configureMenuBar()
                }
        }
    }

    @MainActor
    private func configureMenuBar() {
        appDelegate.configure(appViewModel: appViewModel) {
            openWindow(id: "main")
        }
    }
}
