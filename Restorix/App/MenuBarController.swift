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
        let image = statusImage(symbolNames: statusSymbolNames)
        button.image = image
        button.title = image == nil ? "R" : ""
        button.imagePosition = .imageLeft
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = nil
        button.toolTip = tooltip
        button.setAccessibilityLabel(statusBarTitle)
        statusItem.length = NSStatusItem.squareLength
        statusItem.isVisible = true
    }

    private var statusSymbolNames: [String] {
        if appViewModel?.isScanning == true {
            return ["arrow.triangle.2.circlepath"]
        }

        switch appViewModel?.overallStatus ?? .Unknown {
        case .Protected:
            return ["externaldrive.badge.checkmark", "checkmark.circle", "externaldrive"]
        case .Stale:
            return ["externaldrive.badge.exclamationmark", "exclamationmark.triangle", "externaldrive"]
        case .Unprotected, .Error:
            return ["externaldrive.badge.xmark", "xmark.circle", "externaldrive"]
        case .Unknown:
            return ["externaldrive.badge.questionmark", "questionmark.circle", "externaldrive"]
        }
    }

    private func statusImage(symbolNames: [String]) -> NSImage? {
        for symbolName in symbolNames + ["externaldrive", "shippingbox", "circle"] {
            if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Restorix") {
                image.isTemplate = true
                return image
            }
        }

        return nil
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let summary = appViewModel?.scanResult?.summary

        menu.addItem(disabledTitle("Restorix"))
        menu.addItem(disabledTitle(overallLine))
        menu.addItem(disabledTitle(statusLine(summary)))
        menu.addItem(disabledTitle(lastScanLine(summary)))
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

    private var statusBarTitle: String {
        guard let summary = appViewModel?.scanResult?.summary else {
            return appViewModel?.isScanning == true ? "Restorix ..." : "Restorix"
        }

        if summary.errorCount > 0 || summary.unprotectedCount > 0 {
            return "Restorix \(summary.unprotectedCount + summary.errorCount)!"
        }

        if summary.staleCount > 0 {
            return "Restorix \(summary.staleCount)"
        }

        if summary.unknownCount > 0 {
            return "Restorix \(summary.unknownCount)?"
        }

        return "Restorix OK"
    }

    private func statusLine(_ summary: ScanSummary?) -> String {
        guard let summary else { return text(.statusNotScanned) }
        return "\(text(.statusLine)): \(summary.protectedCount) \(text(.protected)), \(summary.unprotectedCount) \(text(.unprotected)), \(summary.staleCount) \(text(.stale)), \(summary.unknownCount) \(text(.unknown))"
    }

    private func addRiskPreview(to menu: NSMenu) {
        guard let items = appViewModel?.scanResult?.volumeHealth.filter({
            $0.status == .Unprotected || $0.status == .Stale || $0.status == .Unknown || $0.status == .Error
        }), !items.isEmpty else {
            return
        }

        menu.addItem(.separator())
        for item in items.prefix(4) {
            menu.addItem(disabledTitle("• \(item.volume.name): \(statusText(item.status))"))
        }

        if items.count > 4 {
            menu.addItem(disabledTitle("+ \(items.count - 4) \(text(.volumes))"))
        }
    }

    private func lastScanLine(_ summary: ScanSummary?) -> String {
        guard let summary else { return "\(text(.lastScan)): \(text(.never))" }
        return "\(text(.lastScan)): \(relativeDate(summary.scannedAt))"
    }

    private var overallLine: String {
        guard let status = appViewModel?.overallStatus else { return text(.healthUnknown) }
        switch status {
        case .Protected:
            return text(.healthAllProtected)
        case .Stale:
            return text(.healthNeedsReview)
        case .Unprotected, .Error:
            return text(.healthAtRisk)
        case .Unknown:
            return text(.healthUnknown)
        }
    }

    private var tooltip: String {
        guard let summary = appViewModel?.scanResult?.summary else {
            return text(.statusNotScanned)
        }
        return "\(overallLine) - \(summary.totalVolumes) \(text(.volumes))"
    }

    private func text(_ key: L10nKey) -> String {
        appViewModel?.text(key) ?? AppStrings.text(key, language: .english)
    }

    private func statusText(_ status: HealthStatus) -> String {
        switch status {
        case .Protected:
            return text(.protected)
        case .Unprotected:
            return text(.unprotected)
        case .Stale:
            return text(.stale)
        case .Unknown:
            return text(.unknown)
        case .Error:
            return text(.error)
        }
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

    private func relativeDate(_ value: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let date = formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
        guard let date else { return value }

        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .short
        return relative.localizedString(for: date, relativeTo: Date())
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
