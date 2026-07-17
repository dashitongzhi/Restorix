import Foundation
import Combine
import AppKit
import ServiceManagement

@MainActor
final class AppViewModel: ObservableObject {
    @Published var scanResult: ScanResult?
    @Published var repositories: [BackupRepository] = []
    @Published var settings: AppSettings?
    @Published var isScanning = false
    @Published var isLoadingRepositories = false
    @Published var lastError: String?
    @Published var selectedSidebarItem: SidebarItem = .dashboard
    @Published var isAddingRepository = false
    @Published var language: AppLanguage
    @Published var selectedAppIcon: AppIconChoice

    private let coreBridge: CoreBridge

    init(coreBridge: CoreBridge? = nil) {
        self.coreBridge = coreBridge ?? CoreBridge()
        let storedLanguage = UserDefaults.standard.string(forKey: "app.language") ?? AppLanguage.english.rawValue
        self.language = AppLanguage(rawValue: storedLanguage) ?? .english
        self.selectedAppIcon = AppIconChoice.stored()
    }

    func text(_ key: L10nKey) -> String {
        AppStrings.text(key, language: language)
    }

    func setLanguage(_ language: AppLanguage) {
        self.language = language
        UserDefaults.standard.set(language.rawValue, forKey: "app.language")
    }

    func refreshInitialData() async {
        await loadConfig()
        await loadRepositories()
        if scanResult == nil {
            await scanNow()
        }
    }

    func scanNow() async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }
        lastError = nil

        do {
            let result = try await coreBridge.scan()
            scanResult = result
            repositories = result.repositories
            NotificationService.notifyIfNeeded(
                for: result,
                enabled: settings?.notificationsEnabled == true
            )
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadRepositories() async {
        isLoadingRepositories = true
        defer { isLoadingRepositories = false }

        do {
            repositories = try await coreBridge.listRepositories()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func beginAddingRepository() {
        selectedSidebarItem = .repositories
        isAddingRepository = true
    }

    func addRepository(name: String, location: String, passwordEnvKey: String?, password: String?, expectedHostname: String, enabled: Bool) async -> String? {
        do {
            _ = try await coreBridge.addRepository(
                name: name,
                location: location,
                passwordEnvKey: passwordEnvKey,
                password: password,
                expectedHostname: expectedHostname,
                enabled: enabled
            )
            await loadRepositories()
            await scanNow()
            return nil
        } catch {
            let message = error.localizedDescription
            lastError = message
            return message
        }
    }

    func removeRepository(_ repository: BackupRepository) async {
        do {
            _ = try await coreBridge.removeRepository(id: repository.id)
            await loadRepositories()
            await scanNow()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func setRepository(_ repository: BackupRepository, enabled: Bool) async {
        do {
            _ = try await coreBridge.setRepositoryEnabled(id: repository.id, enabled: enabled)
            await loadRepositories()
            await scanNow()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func testRepository(_ repository: BackupRepository) async -> Int? {
        do {
            let snapshots = try await coreBridge.testRepository(id: repository.id)
            return snapshots.count
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func exportMarkdownReport() async -> String? {
        if let scanResult {
            return MarkdownReportRenderer.render(
                scanResult,
                language: language,
                repositoryName: repositoryDisplayName(for:)
            )
        }

        do {
            return try await coreBridge.exportMarkdownReport(language: language)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func loadConfig() async {
        do {
            let loadedSettings = try await coreBridge.getConfig()
            settings = await settingsByReconcilingLaunchAtLogin(loadedSettings)
            applyDockIconPreference(settings?.showDockIcon == true)
            applySelectedAppIcon()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func setConfig(key: String, value: String) async {
        do {
            let updatedSettings = try await coreBridge.setConfig(key: key, value: value)
            settings = await settingsByReconcilingLaunchAtLogin(updatedSettings)
            if key == "show_dock_icon" {
                applyDockIconPreference(settings?.showDockIcon == true)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) async {
        do {
            try applyLaunchAtLoginPreference(enabled)
        } catch {
            lastError = error.localizedDescription
        }

        await refreshLaunchAtLoginSettingFromSystem()
    }

    func applyDockIconPreference(_ showDockIcon: Bool) {
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
        if showDockIcon {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applyLaunchAtLoginPreference(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            if service.status != .enabled {
                try service.register()
            }
        } else if service.status == .enabled || service.status == .requiresApproval {
            try service.unregister()
        }
    }

    private func refreshLaunchAtLoginSettingFromSystem() async {
        guard let settings else {
            await loadConfig()
            return
        }

        self.settings = await settingsByReconcilingLaunchAtLogin(settings)
    }

    private func settingsByReconcilingLaunchAtLogin(_ loadedSettings: AppSettings) async -> AppSettings {
        let systemEnabled = SMAppService.mainApp.status == .enabled
        guard loadedSettings.launchAtLogin != systemEnabled else {
            return loadedSettings
        }

        do {
            return try await coreBridge.setConfig(
                key: "launch_at_login",
                value: systemEnabled ? "true" : "false"
            )
        } catch {
            lastError = error.localizedDescription
            var fallback = loadedSettings
            fallback.launchAtLogin = systemEnabled
            return fallback
        }
    }

    func selectAppIcon(_ icon: AppIconChoice) {
        selectedAppIcon = icon.image == nil ? .default : icon
        selectedAppIcon.save()
        applySelectedAppIcon()
    }

    func applySelectedAppIcon() {
        guard let image = selectedAppIcon.image ?? AppIconChoice.default.image else {
            return
        }

        if selectedAppIcon.image == nil {
            selectedAppIcon = .default
            selectedAppIcon.save()
        }

        NSApp.applicationIconImage = image
    }

    var overallStatus: HealthStatus {
        guard let result = scanResult else {
            return .Unknown
        }

        let summary = result.summary
        if !result.errors.isEmpty {
            return .Error
        }

        if summary.errorCount > 0 || summary.unprotectedCount > 0 {
            return .Error
        }

        if summary.staleCount > 0 || summary.unknownCount > 0 {
            return .Stale
        }

        return .Protected
    }

    var dockerStateText: String {
        guard let result = scanResult else { return text(.notScanned) }
        if result.summary.dockerRunning {
            return text(.dockerRunning)
        }
        return result.summary.dockerAvailable ? text(.dockerNotRunning) : text(.dockerMissing)
    }

    var dockerStateIsHealthy: Bool {
        scanResult?.summary.dockerRunning == true
    }

    var resticStateText: String {
        guard let result = scanResult else { return text(.notScanned) }
        return result.summary.resticAvailable ? text(.resticAvailable) : text(.resticMissing)
    }

    func repositoryDisplayName(for id: String?) -> String {
        guard let id else { return text(.none) }
        return repositories.first(where: { $0.id == id })?.name ?? id
    }

    var riskyVolumes: [VolumeHealth] {
        scanResult?.volumeHealth.filter { item in
            item.status == .Unprotected || item.status == .Stale || item.status == .Error
        } ?? []
    }
}
