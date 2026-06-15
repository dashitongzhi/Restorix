import SwiftUI

@main
struct RestorixApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @StateObject private var appViewModel: AppViewModel

    init() {
        let appViewModel = AppViewModel()
        _appViewModel = StateObject(wrappedValue: appViewModel)
        Task { @MainActor in
            await appViewModel.loadConfig()
        }
    }

    var body: some Scene {
        WindowGroup("Restorix", id: "main") {
            RootView()
                .environmentObject(appViewModel)
                .frame(minWidth: 980, minHeight: 640)
                .onAppear {
                    appDelegate.configure(appViewModel: appViewModel) {
                        openWindow(id: "main")
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Restorix") {
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
                .frame(width: 560, height: 500)
        }
    }
}
