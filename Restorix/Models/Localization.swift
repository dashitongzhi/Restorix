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
    case appIconOrbitCheck
    case appIconVaultSeal
    case appIconSnapshotLayers
    case appIconTimeCapsule
    case appIconIntegrityPrism
    case appIconSignalArchive
    case appIconMinimalRibbon
    case appIconChecksumWave
    case backupHealthUnknown
    case backupNeedsAttention
    case cancel
    case cli
    case cliPath
    case chooseFolder
    case confidence
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
    case password
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
    case snapshotHostname
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
    case configureCLI
    case envNameOnly
    case openDocker
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
    case reviewVolumes
}

enum AppStrings {
    static func text(_ key: L10nKey, language: AppLanguage) -> String {
        switch language {
        case .english:
            return EnglishStrings.values[key] ?? key.rawValue
        case .simplifiedChinese:
            return SimplifiedChineseStrings.values[key] ?? EnglishStrings.values[key] ?? key.rawValue
        }
    }

    static func text(_ key: L10nKey, languageCode: String) -> String {
        text(key, language: AppLanguage(rawValue: languageCode) ?? .english)
    }
}
