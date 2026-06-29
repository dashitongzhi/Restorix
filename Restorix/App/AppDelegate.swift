import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    @MainActor
    func configure(appViewModel: AppViewModel, openDashboard: @escaping @MainActor () -> Void) {
        guard menuBarController == nil else { return }
        menuBarController = MenuBarController(appViewModel: appViewModel, openDashboard: openDashboard)
        appViewModel.applySelectedAppIcon()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
