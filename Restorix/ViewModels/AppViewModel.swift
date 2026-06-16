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
        let storedAppIcon = UserDefaults.standard.string(forKey: AppIconChoice.userDefaultsKey) ?? AppIconChoice.default.rawValue
        self.selectedAppIcon = AppIconChoice(rawValue: storedAppIcon) ?? .default
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

    func addRepository(name: String, location: String, passwordEnvKey: String?, enabled: Bool) async {
        do {
            _ = try await coreBridge.addRepository(
                name: name,
                location: location,
                passwordEnvKey: passwordEnvKey,
                enabled: enabled
            )
            await loadRepositories()
            await scanNow()
        } catch {
            lastError = error.localizedDescription
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
        selectedAppIcon = icon
        UserDefaults.standard.set(icon.rawValue, forKey: AppIconChoice.userDefaultsKey)
        applySelectedAppIcon()
    }

    func applySelectedAppIcon() {
        guard let image = NSImage(named: NSImage.Name(selectedAppIcon.assetName)) else {
            return
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

private enum MarkdownReportRenderer {
    static func render(
        _ result: ScanResult,
        language: AppLanguage,
        repositoryName: (String?) -> String
    ) -> String {
        var lines: [String] = []
        let summary = result.summary

        lines.append("# \(label(.report, language))")
        lines.append("\(label(.generatedAt, language)): \(summary.scannedAt)")
        lines.append("")
        lines.append("## \(label(.summary, language))")
        lines.append("- Docker \(label(.available, language)): \(yesNo(summary.dockerAvailable, language))")
        lines.append("- Docker \(label(.running, language)): \(yesNo(summary.dockerRunning, language))")
        lines.append("- Restic \(label(.available, language)): \(yesNo(summary.resticAvailable, language))")
        lines.append("- \(label(.totalContainers, language)): \(summary.totalContainers)")
        lines.append("- \(label(.totalVolumes, language)): \(summary.totalVolumes)")
        lines.append("- \(label(.protected, language)): \(summary.protectedCount)")
        lines.append("- \(label(.unprotected, language)): \(summary.unprotectedCount)")
        lines.append("- \(label(.stale, language)): \(summary.staleCount)")
        lines.append("- \(label(.unknown, language)): \(summary.unknownCount)")
        lines.append("- \(label(.errors, language)): \(summary.errorCount)")
        lines.append("")

        appendVolumeTable(
            title: label(.unprotectedVolumes, language),
            items: result.volumeHealth.filter { $0.status == .Unprotected },
            language: language,
            repositoryName: repositoryName,
            lines: &lines
        )
        appendVolumeTable(
            title: label(.staleVolumes, language),
            items: result.volumeHealth.filter { $0.status == .Stale },
            language: language,
            repositoryName: repositoryName,
            lines: &lines
        )
        appendVolumeTable(
            title: label(.unknownVolumes, language),
            items: result.volumeHealth.filter { $0.status == .Unknown },
            language: language,
            repositoryName: repositoryName,
            lines: &lines
        )
        appendVolumeTable(
            title: label(.protectedVolumes, language),
            items: result.volumeHealth.filter { $0.status == .Protected },
            language: language,
            repositoryName: repositoryName,
            lines: &lines
        )
        appendRestoreCommands(result.volumeHealth, language: language, lines: &lines)
        appendMessages(title: label(.warnings, language), messages: result.warnings, lines: &lines)
        appendMessages(title: label(.errors, language), messages: result.errors, lines: &lines)

        return lines.joined(separator: "\n") + "\n"
    }

    private static func appendVolumeTable(
        title: String,
        items: [VolumeHealth],
        language: AppLanguage,
        repositoryName: (String?) -> String,
        lines: inout [String]
    ) {
        guard !items.isEmpty else { return }
        lines.append("## \(title)")
        lines.append("| \(label(.volume, language)) | \(label(.status, language)) | \(label(.lastBackup, language)) | \(label(.repository, language)) | \(label(.reason, language)) |")
        lines.append("|---|---|---|---|---|")
        for item in items {
            lines.append(
                "| \(escape(item.volume.name)) | \(statusText(item.status, language)) | \(escape(item.lastBackupTime ?? label(.never, language))) | \(escape(repositoryName(item.matchedRepositoryId))) | \(escape(item.reason)) |"
            )
        }
        lines.append("")
    }

    private static func appendRestoreCommands(
        _ items: [VolumeHealth],
        language: AppLanguage,
        lines: inout [String]
    ) {
        let commands = items.filter { $0.restoreCommand != nil }
        guard !commands.isEmpty else { return }
        lines.append("## \(label(.restoreCommands, language))")
        for item in commands {
            lines.append("### \(item.volume.name)")
            lines.append("```bash")
            lines.append(item.restoreCommand ?? "")
            lines.append("```")
        }
        lines.append("")
    }

    private static func appendMessages(title: String, messages: [String], lines: inout [String]) {
        guard !messages.isEmpty else { return }
        lines.append("## \(title)")
        for message in messages {
            lines.append("- \(message)")
        }
        lines.append("")
    }

    private static func statusText(_ status: HealthStatus, _ language: AppLanguage) -> String {
        switch status {
        case .Protected:
            return label(.protected, language)
        case .Unprotected:
            return label(.unprotected, language)
        case .Stale:
            return label(.stale, language)
        case .Unknown:
            return label(.unknown, language)
        case .Error:
            return label(.errors, language)
        }
    }

    private static func yesNo(_ value: Bool, _ language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            return value ? "是" : "否"
        }
        return value ? "Yes" : "No"
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private static func label(_ label: Label, _ language: AppLanguage) -> String {
        switch (language, label) {
        case (.simplifiedChinese, .available): return "可用"
        case (.simplifiedChinese, .errors): return "错误"
        case (.simplifiedChinese, .generatedAt): return "生成时间"
        case (.simplifiedChinese, .lastBackup): return "最近备份"
        case (.simplifiedChinese, .never): return "从未"
        case (.simplifiedChinese, .protected): return "已保护"
        case (.simplifiedChinese, .protectedVolumes): return "已保护 Volumes"
        case (.simplifiedChinese, .reason): return "原因"
        case (.simplifiedChinese, .report): return "Restorix 报告"
        case (.simplifiedChinese, .repository): return "仓库"
        case (.simplifiedChinese, .restoreCommands): return "恢复命令"
        case (.simplifiedChinese, .running): return "运行中"
        case (.simplifiedChinese, .stale): return "已过期"
        case (.simplifiedChinese, .staleVolumes): return "已过期 Volumes"
        case (.simplifiedChinese, .status): return "状态"
        case (.simplifiedChinese, .summary): return "摘要"
        case (.simplifiedChinese, .totalContainers): return "容器总数"
        case (.simplifiedChinese, .totalVolumes): return "Volume 总数"
        case (.simplifiedChinese, .unknown): return "未知"
        case (.simplifiedChinese, .unknownVolumes): return "未知 Volumes"
        case (.simplifiedChinese, .unprotected): return "未保护"
        case (.simplifiedChinese, .unprotectedVolumes): return "未保护 Volumes"
        case (.simplifiedChinese, .volume): return "Volume"
        case (.simplifiedChinese, .warnings): return "警告"
        case (_, .available): return "available"
        case (_, .errors): return "Errors"
        case (_, .generatedAt): return "Generated at"
        case (_, .lastBackup): return "Last Backup"
        case (_, .never): return "Never"
        case (_, .protected): return "Protected"
        case (_, .protectedVolumes): return "Protected Volumes"
        case (_, .reason): return "Reason"
        case (_, .report): return "Restorix Report"
        case (_, .repository): return "Repository"
        case (_, .restoreCommands): return "Restore Commands"
        case (_, .running): return "running"
        case (_, .stale): return "Stale"
        case (_, .staleVolumes): return "Stale Volumes"
        case (_, .status): return "Status"
        case (_, .summary): return "Summary"
        case (_, .totalContainers): return "Total containers"
        case (_, .totalVolumes): return "Total volumes"
        case (_, .unknown): return "Unknown"
        case (_, .unknownVolumes): return "Unknown Volumes"
        case (_, .unprotected): return "Unprotected"
        case (_, .unprotectedVolumes): return "Unprotected Volumes"
        case (_, .volume): return "Volume"
        case (_, .warnings): return "Warnings"
        }
    }

    private enum Label {
        case available
        case errors
        case generatedAt
        case lastBackup
        case never
        case protected
        case protectedVolumes
        case reason
        case report
        case repository
        case restoreCommands
        case running
        case stale
        case staleVolumes
        case status
        case summary
        case totalContainers
        case totalVolumes
        case unknown
        case unknownVolumes
        case unprotected
        case unprotectedVolumes
        case volume
        case warnings
    }
}
