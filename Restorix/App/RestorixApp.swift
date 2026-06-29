import SwiftUI

@main
struct RestorixApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @StateObject private var appViewModel = AppViewModel()

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
