import AppKit
import Combine

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let openDashboardWindow: @MainActor () -> Void
    private weak var appViewModel: AppViewModel?
    private var cancellables = Set<AnyCancellable>()

    init(appViewModel: AppViewModel, openDashboard: @escaping @MainActor () -> Void) {
        self.appViewModel = appViewModel
        self.openDashboardWindow = openDashboard
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureButton()
        rebuildMenu()

        appViewModel.$scanResult
            .combineLatest(appViewModel.$isScanning, appViewModel.$lastError)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _ in
                self?.configureButton()
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        appViewModel.$language
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.configureButton()
                self?.rebuildMenu()
            }
            .store(in: &cancellables)
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        let imageName = appViewModel?.isScanning == true ? "arrow.triangle.2.circlepath" : "externaldrive.connected.to.line.below"
        let image = statusImage(preferredName: imageName)
        button.image = image
        button.title = image == nil ? "R" : ""
        button.imagePosition = .imageLeft
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = nil
        button.toolTip = presentation.tooltip
        button.setAccessibilityLabel(presentation.statusBarTitle)
        statusItem.length = NSStatusItem.squareLength
        statusItem.isVisible = true
    }

    private func statusImage(preferredName: String) -> NSImage? {
        for symbolName in [preferredName, "externaldrive", "shippingbox", "checkmark.shield", "circle"] {
            if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Restorix") {
                image.isTemplate = true
                return image
            }
        }

        return nil
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(disabledTitle("Restorix"))
        menu.addItem(disabledTitle(presentation.overallLine))
        menu.addItem(disabledTitle(presentation.statusLine))
        menu.addItem(disabledTitle(presentation.lastScanLine))
        addRiskPreview(to: menu)
        menu.addItem(.separator())
        menu.addItem(actionItem(text(.openDashboard), #selector(openDashboard)))
        menu.addItem(actionItem(text(.openVolumes), #selector(openVolumes), enabled: appViewModel?.scanResult != nil))
        menu.addItem(actionItem(appViewModel?.isScanning == true ? text(.scanning) : text(.scanNow), #selector(scanNow), enabled: appViewModel?.isScanning != true))
        menu.addItem(actionItem(text(.exportReport), #selector(exportReport), enabled: appViewModel?.scanResult != nil))
        menu.addItem(.separator())
        menu.addItem(disabledTitle("\(text(.docker)): \(appViewModel?.dockerStateText ?? text(.unknown))"))
        menu.addItem(disabledTitle("\(text(.restic)): \(appViewModel?.resticStateText ?? text(.unknown))"))
        menu.addItem(.separator())
        menu.addItem(actionItem(text(.settings), #selector(openSettings)))
        menu.addItem(actionItem(text(.quit), #selector(quit)))

        statusItem.menu = menu
    }

    private func addRiskPreview(to menu: NSMenu) {
        let items = presentation.riskyVolumes
        guard !items.isEmpty else { return }

        menu.addItem(.separator())
        for item in items.prefix(4) {
            menu.addItem(disabledTitle("• \(item.volume.name): \(presentation.statusText(item.status))"))
        }

        if items.count > 4 {
            menu.addItem(disabledTitle("+ \(items.count - 4) \(text(.volumes))"))
        }
    }

    private func text(_ key: L10nKey) -> String {
        appViewModel?.text(key) ?? AppStrings.text(key, language: .english)
    }

    private var presentation: MenuBarPresentation {
        MenuBarPresentation(
            result: appViewModel?.scanResult,
            isScanning: appViewModel?.isScanning == true,
            language: appViewModel?.language ?? .english
        )
    }

    private func disabledTitle(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(_ title: String, _ action: Selector, enabled: Bool = true) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = enabled
        return item
    }

    @objc private func openDashboard() {
        appViewModel?.selectedSidebarItem = .dashboard
        openDashboardWindow()
        WindowManager.openDashboard()
    }

    @objc private func openVolumes() {
        appViewModel?.selectedSidebarItem = .volumes
        openDashboardWindow()
        WindowManager.openDashboard()
    }

    @objc private func scanNow() {
        guard let appViewModel else { return }
        Task {
            await appViewModel.scanNow()
        }
    }

    @objc private func exportReport() {
        guard let appViewModel else { return }
        Task {
            if let report = await appViewModel.exportMarkdownReport() {
                Pasteboard.copy(report)
            }
        }
    }

    @objc private func openSettings() {
        WindowManager.openSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
