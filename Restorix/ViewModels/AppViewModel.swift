import Foundation
import Combine
import AppKit

@MainActor
final class AppViewModel: ObservableObject {
    @Published var scanResult: ScanResult?
    @Published var repositories: [BackupRepository] = []
    @Published var settings: AppSettings?
    @Published var isScanning = false
    @Published var isLoadingRepositories = false
    @Published var lastError: String?
    @Published var selectedSidebarItem: SidebarItem = .dashboard
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

        isScanning = false
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

    func addRepository(name: String, location: String, passwordEnvKey: String?, enabled: Bool) async {
        do {
            _ = try await coreBridge.addRepository(
                name: name,
                location: location,
                passwordEnvKey: passwordEnvKey,
                enabled: enabled
            )
            await loadRepositories()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func exportMarkdownReport() async -> String? {
        do {
            return try await coreBridge.exportMarkdownReport(language: language)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func loadConfig() async {
        do {
            settings = try await coreBridge.getConfig()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func setConfig(key: String, value: String) async {
        do {
            settings = try await coreBridge.setConfig(key: key, value: value)
        } catch {
            lastError = error.localizedDescription
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

    var riskyVolumes: [VolumeHealth] {
        scanResult?.volumeHealth.filter { item in
            item.status == .Unprotected || item.status == .Stale || item.status == .Error
        } ?? []
    }
}
