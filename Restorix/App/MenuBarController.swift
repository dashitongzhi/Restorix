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
        button.image = NSImage(systemSymbolName: imageName, accessibilityDescription: "Restorix")
        button.imagePosition = .imageOnly
        button.contentTintColor = color(for: appViewModel?.overallStatus ?? .Unknown)
        button.toolTip = tooltip
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let summary = appViewModel?.scanResult?.summary

        menu.addItem(disabledTitle("Restorix"))
        menu.addItem(disabledTitle(overallLine))
        menu.addItem(disabledTitle(statusLine(summary)))
        menu.addItem(disabledTitle(lastScanLine(summary)))
        menu.addItem(.separator())
        menu.addItem(actionItem(text(.openDashboard), #selector(openDashboard)))
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

    private func statusLine(_ summary: ScanSummary?) -> String {
        guard let summary else { return text(.statusNotScanned) }
        return "\(text(.statusLine)): \(summary.protectedCount) \(text(.protected)), \(summary.unprotectedCount) \(text(.unprotected)), \(summary.staleCount) \(text(.stale))"
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

    private func color(for status: HealthStatus) -> NSColor {
        switch status {
        case .Protected:
            return .systemGreen
        case .Stale:
            return .systemYellow
        case .Unprotected, .Error:
            return .systemRed
        case .Unknown:
            return .systemGray
        }
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
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
