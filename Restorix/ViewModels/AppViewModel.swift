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
    @Published var isAddingRepository = false
    @Published private(set) var isCommittingSettings = false
    @Published var language: AppLanguage
    @Published var selectedAppIcon: AppIconChoice

    private let workflow: any AppWorkflowing
    private let settingsCoordinator: SettingsCoordinator

    init(
        coreBridge: (any CoreBridging)? = nil,
        systemPreferences: (any SystemPreferencesApplying)? = nil,
        notificationCoordinator: NotificationCoordinator? = nil,
        workflow: (any AppWorkflowing)? = nil
    ) {
        let resolvedCoreBridge = coreBridge ?? CoreBridge()
        self.settingsCoordinator = SettingsCoordinator(
            coreBridge: resolvedCoreBridge,
            systemPreferences: systemPreferences ?? MacSystemPreferencesAdapter()
        )
        self.workflow = workflow ?? AppWorkflow(
            coreBridge: resolvedCoreBridge,
            notificationCoordinator: notificationCoordinator ?? NotificationCoordinator()
        )
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
            apply(try await workflow.scan(
                notificationsEnabled: settings?.notificationsEnabled == true,
                language: language
            ))
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadRepositories() async {
        isLoadingRepositories = true
        defer { isLoadingRepositories = false }

        do {
            repositories = try await workflow.loadRepositories()
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
            apply(try await workflow.addRepository(
                name: name,
                location: location,
                passwordEnvKey: passwordEnvKey,
                password: password,
                expectedHostname: expectedHostname,
                enabled: enabled,
                notificationsEnabled: settings?.notificationsEnabled == true,
                language: language
            ))
            return nil
        } catch {
            let message = error.localizedDescription
            await loadRepositories()
            lastError = message
            return message
        }
    }

    func removeRepository(_ repository: BackupRepository) async {
        do {
            apply(try await workflow.removeRepository(
                id: repository.id,
                notificationsEnabled: settings?.notificationsEnabled == true,
                language: language
            ))
        } catch {
            let message = error.localizedDescription
            await loadRepositories()
            lastError = message
        }
    }

    func setRepository(_ repository: BackupRepository, enabled: Bool) async {
        do {
            apply(try await workflow.setRepositoryEnabled(
                id: repository.id,
                enabled: enabled,
                notificationsEnabled: settings?.notificationsEnabled == true,
                language: language
            ))
        } catch {
            let message = error.localizedDescription
            await loadRepositories()
            lastError = message
        }
    }

    func testRepository(_ repository: BackupRepository) async -> Int? {
        do {
            let snapshots = try await workflow.testRepository(id: repository.id)
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
            return try await workflow.exportMarkdownReport(language: language)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func loadConfig() async {
        do {
            settings = try await settingsCoordinator.load()
            applySelectedAppIcon()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func apply(_ state: AppScanState) {
        scanResult = state.result
        repositories = state.repositories
    }

    private func apply(_ outcome: AppMutationOutcome) {
        if let result = outcome.result {
            scanResult = result
        }
        if let refreshedRepositories = outcome.repositories {
            repositories = refreshedRepositories
        }
        lastError = outcome.refreshWarning
    }

    @discardableResult
    func commitSettings(_ draft: SettingsDraft) async -> Bool {
        guard !isCommittingSettings else { return false }
        isCommittingSettings = true
        defer { isCommittingSettings = false }
        lastError = nil
        do {
            settings = try await settingsCoordinator.commit(draft)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
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
        ScanPresentation.overallStatus(for: scanResult)
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
        scanResult.map(VolumeRiskPolicy.itemsRequiringAttention(in:)) ?? []
    }
}
