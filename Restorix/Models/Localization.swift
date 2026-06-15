import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }
}

enum L10nKey: String {
    case add
    case addRepository
    case allProtected
    case appIcon
    case appIconDefault
    case appIconDimensional
    case appIconGlass
    case appIconNeon
    case backupHealthUnknown
    case backupNeedsAttention
    case cancel
    case cli
    case cliPath
    case containers
    case copy
    case copyCommand
    case copyRestoreCommand
    case copied
    case criticalIssues
    case dashboard
    case docker
    case dockerMissing
    case dockerNotRunning
    case dockerRunning
    case dockerStartDetail
    case dockerStartTitle
    case enabled
    case disabled
    case enable
    case disable
    case error
    case exportReport
    case generate
    case generateReport
    case healthAllProtected
    case healthAtRisk
    case healthNeedsReview
    case healthUnknown
    case installResticDetail
    case installResticTitle
    case language
    case lastBackup
    case lastScan
    case launchAtLogin
    case localNotifications
    case looseMatching
    case markdownReport
    case name
    case noReportGenerated
    case noReportGeneratedMessage
    case noRepositoriesConfigured
    case noRepositoriesConfiguredMessage
    case noRiskyVolumes
    case noScanResults
    case noScanResultsMessage
    case noVolumesFound
    case noVolumesFoundMessage
    case none
    case notSet
    case notScanned
    case nextSteps
    case openDashboard
    case openVolumes
    case productSubtitle
    case passwordEnv
    case protected
    case reason
    case repositories
    case repositoryLocation
    case reportGenerateMessage
    case reports
    case restic
    case resticAvailable
    case resticMissing
    case resticRepoAddDetail
    case resticRepoAddTitle
    case restoreCommand
    case safeRestoreCommand
    case save
    case saveSettings
    case scan
    case scanNow
    case scanSettings
    case scanning
    case settings
    case staleThreshold
    case statusNotScanned
    case statusLine
    case status
    case systemDefault
    case unknownReviewDetail
    case unknownReviewTitle
    case unknown
    case unprotected
    case volume
    case volumeHealth
    case volumes
    case volumesAtRisk
    case warnings
    case stale
    case hours
    case cliHint
    case envNameOnly
    case quit
    case never
    case repository
    case remove
    case removeRepository
    case repositoryReady
    case repositoryTestFailed
    case showDockIcon
    case snapshots
    case testRepository
    case testing
}

enum AppStrings {
    static func text(_ key: L10nKey, language: AppLanguage) -> String {
        switch language {
        case .english:
            return english[key] ?? key.rawValue
        case .simplifiedChinese:
            return simplifiedChinese[key] ?? english[key] ?? key.rawValue
        }
    }

    static func text(_ key: L10nKey, languageCode: String) -> String {
        text(key, language: AppLanguage(rawValue: languageCode) ?? .english)
    }

    private static let english: [L10nKey: String] = [
        .add: "Add",
        .addRepository: "Add Restic Repository",
        .allProtected: "All protected",
        .appIcon: "App Icon",
        .appIconDefault: "Default",
        .appIconDimensional: "Dimensional",
        .appIconGlass: "Glass",
        .appIconNeon: "Neon",
        .backupHealthUnknown: "Backup health unknown",
        .backupNeedsAttention: "Backup needs attention",
        .cancel: "Cancel",
        .cli: "CLI",
        .cliPath: "CLI path",
        .containers: "Containers",
        .copy: "Copy",
        .copyCommand: "Copy command",
        .copyRestoreCommand: "Copy Restore Command",
        .copied: "Copied",
        .criticalIssues: "Critical Issues",
        .dashboard: "Dashboard",
        .docker: "Docker",
        .dockerMissing: "Missing",
        .dockerNotRunning: "Not running",
        .dockerRunning: "Running",
        .dockerStartDetail: "Restorix can only inspect containers and volumes while the Docker daemon is running.",
        .dockerStartTitle: "Start Docker or OrbStack",
        .enabled: "Enabled",
        .disabled: "Disabled",
        .enable: "Enable",
        .disable: "Disable",
        .error: "Error",
        .exportReport: "Export Report",
        .generate: "Generate",
        .generateReport: "Generate Report",
        .healthAllProtected: "Health: All protected",
        .healthAtRisk: "Health: At risk",
        .healthNeedsReview: "Health: Needs review",
        .healthUnknown: "Health: Unknown",
        .installResticDetail: "Restorix uses restic snapshots to verify whether Docker volumes are backed up.",
        .installResticTitle: "Install restic",
        .language: "Language",
        .lastBackup: "Last Backup",
        .lastScan: "Last scan",
        .launchAtLogin: "Open at login",
        .localNotifications: "Local notifications",
        .looseMatching: "Loose matching",
        .markdownReport: "Markdown Report",
        .name: "Name",
        .noReportGenerated: "No report generated",
        .noReportGeneratedMessage: "Generate a Markdown report from the latest scan result.",
        .noRepositoriesConfigured: "No repositories configured",
        .noRepositoriesConfiguredMessage: "Add a restic repository so Restorix can compare snapshots with Docker volumes.",
        .noRiskyVolumes: "No risky volumes found in the latest scan.",
        .noScanResults: "No scan results yet",
        .noScanResultsMessage: "Run your first scan to check whether your Docker volumes are protected.",
        .noVolumesFound: "No volumes found",
        .noVolumesFoundMessage: "Run a scan after Docker is running to inspect Docker volume health.",
        .none: "None",
        .notSet: "Not set",
        .notScanned: "Not scanned",
        .nextSteps: "Next Steps",
        .openDashboard: "Open Dashboard",
        .openVolumes: "Open Volumes",
        .productSubtitle: "Restorix checks whether Docker volumes are actually restorable.",
        .passwordEnv: "Password env",
        .protected: "Protected",
        .reason: "Reason",
        .repositories: "Repositories",
        .repositoryLocation: "Repository Location",
        .reportGenerateMessage: "Generate a Markdown report from the latest scan result.",
        .reports: "Reports",
        .restic: "Restic",
        .resticAvailable: "Available",
        .resticMissing: "Missing",
        .resticRepoAddDetail: "Without a repository, Restorix can list volumes but cannot prove that any backup exists.",
        .resticRepoAddTitle: "Add a restic repository",
        .restoreCommand: "Restore command",
        .safeRestoreCommand: "Safe restore command",
        .save: "Save",
        .saveSettings: "Save Settings",
        .scan: "Scan",
        .scanNow: "Scan Now",
        .scanSettings: "Scan",
        .scanning: "Scanning",
        .settings: "Settings",
        .staleThreshold: "Stale threshold",
        .statusNotScanned: "Status: Not scanned",
        .statusLine: "Status",
        .status: "Status",
        .systemDefault: "System default",
        .unknownReviewDetail: "Unknown means Restorix could not find enough reliable snapshot evidence yet.",
        .unknownReviewTitle: "Review unknown volumes",
        .unknown: "Unknown",
        .unprotected: "Unprotected",
        .volume: "Volume",
        .volumeHealth: "Volume Health",
        .volumes: "Volumes",
        .volumesAtRisk: "Volumes at risk",
        .warnings: "Warnings",
        .stale: "Stale",
        .hours: "hours",
        .cliHint: "Leave empty to use the bundled restorix binary or Homebrew fallback.",
        .envNameOnly: "Restorix stores the environment variable name, not your password.",
        .quit: "Quit",
        .never: "Never",
        .repository: "Repository",
        .remove: "Remove",
        .removeRepository: "Remove Repository",
        .repositoryReady: "Repository is reachable",
        .repositoryTestFailed: "Repository test failed",
        .showDockIcon: "Show Dock icon",
        .snapshots: "snapshots",
        .testRepository: "Test Repository",
        .testing: "Testing"
    ]

    private static let simplifiedChinese: [L10nKey: String] = [
        .add: "添加",
        .addRepository: "添加 Restic 仓库",
        .allProtected: "全部已保护",
        .appIcon: "应用图标",
        .appIconDefault: "默认",
        .appIconDimensional: "立体",
        .appIconGlass: "玻璃",
        .appIconNeon: "霓虹",
        .backupHealthUnknown: "备份健康状态未知",
        .backupNeedsAttention: "备份需要关注",
        .cancel: "取消",
        .cli: "CLI",
        .cliPath: "CLI 路径",
        .containers: "容器",
        .copy: "复制",
        .copyCommand: "复制命令",
        .copyRestoreCommand: "复制恢复命令",
        .copied: "已复制",
        .criticalIssues: "关键问题",
        .dashboard: "仪表盘",
        .docker: "Docker",
        .dockerMissing: "未安装",
        .dockerNotRunning: "未运行",
        .dockerRunning: "运行中",
        .dockerStartDetail: "只有 Docker daemon 正在运行时，Restorix 才能检查容器和 volume。",
        .dockerStartTitle: "启动 Docker 或 OrbStack",
        .enabled: "已启用",
        .disabled: "已停用",
        .enable: "启用",
        .disable: "停用",
        .error: "错误",
        .exportReport: "导出报告",
        .generate: "生成",
        .generateReport: "生成报告",
        .healthAllProtected: "健康：全部已保护",
        .healthAtRisk: "健康：有风险",
        .healthNeedsReview: "健康：需要检查",
        .healthUnknown: "健康：未知",
        .installResticDetail: "Restorix 使用 restic snapshots 来确认 Docker volumes 是否真的被备份。",
        .installResticTitle: "安装 restic",
        .language: "语言",
        .lastBackup: "最近备份",
        .lastScan: "最近扫描",
        .launchAtLogin: "登录时打开",
        .localNotifications: "本地通知",
        .looseMatching: "宽松匹配",
        .markdownReport: "Markdown 报告",
        .name: "名称",
        .noReportGenerated: "还没有生成报告",
        .noReportGeneratedMessage: "基于最近一次扫描生成 Markdown 健康报告。",
        .noRepositoriesConfigured: "还没有配置仓库",
        .noRepositoriesConfiguredMessage: "添加一个 restic 仓库后，Restorix 才能把 snapshots 和 Docker volumes 进行比对。",
        .noRiskyVolumes: "最近一次扫描没有发现高风险 volume。",
        .noScanResults: "还没有扫描结果",
        .noScanResultsMessage: "运行第一次扫描，检查 Docker volumes 是否被保护。",
        .noVolumesFound: "没有发现 volumes",
        .noVolumesFoundMessage: "Docker 运行后再扫描，Restorix 会检查 Docker volume 健康状态。",
        .none: "无",
        .notSet: "未设置",
        .notScanned: "未扫描",
        .nextSteps: "下一步",
        .openDashboard: "打开仪表盘",
        .openVolumes: "打开 Volumes",
        .productSubtitle: "Restorix 会检查 Docker volumes 是否真的可恢复。",
        .passwordEnv: "密码环境变量",
        .protected: "已保护",
        .reason: "原因",
        .repositories: "仓库",
        .repositoryLocation: "仓库位置",
        .reportGenerateMessage: "基于最近一次扫描生成 Markdown 健康报告。",
        .reports: "报告",
        .restic: "Restic",
        .resticAvailable: "可用",
        .resticMissing: "未安装",
        .resticRepoAddDetail: "没有仓库时，Restorix 可以列出 volumes，但无法证明备份存在。",
        .resticRepoAddTitle: "添加 restic 仓库",
        .restoreCommand: "恢复命令",
        .safeRestoreCommand: "安全恢复命令",
        .save: "保存",
        .saveSettings: "保存设置",
        .scan: "扫描",
        .scanNow: "立即扫描",
        .scanSettings: "扫描",
        .scanning: "扫描中",
        .settings: "设置",
        .staleThreshold: "过期阈值",
        .statusNotScanned: "状态：未扫描",
        .statusLine: "状态",
        .status: "状态",
        .systemDefault: "跟随系统",
        .unknownReviewDetail: "Unknown 表示 Restorix 还没有找到足够可靠的 snapshot 证据。",
        .unknownReviewTitle: "检查未知 volumes",
        .unknown: "未知",
        .unprotected: "未保护",
        .volume: "Volume",
        .volumeHealth: "Volume 健康",
        .volumes: "Volumes",
        .volumesAtRisk: "Volumes 有风险",
        .warnings: "警告",
        .stale: "已过期",
        .hours: "小时",
        .cliHint: "留空时使用 App 内置的 restorix，或 Homebrew 路径中的 restorix。",
        .envNameOnly: "Restorix 只保存环境变量名称，不保存你的密码。",
        .quit: "退出",
        .never: "从未",
        .repository: "仓库",
        .remove: "删除",
        .removeRepository: "删除仓库",
        .repositoryReady: "仓库可访问",
        .repositoryTestFailed: "仓库测试失败",
        .showDockIcon: "显示 Dock 图标",
        .snapshots: "个 snapshots",
        .testRepository: "测试仓库",
        .testing: "测试中"
    ]
}
