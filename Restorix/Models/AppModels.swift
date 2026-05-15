import Foundation

enum Platform: String, Codable {
    case MacOS
    case Windows
    case Linux
    case Unknown
}

enum BackupTool: String, Codable {
    case Restic
    case Borg
    case Rclone
    case Unknown
}

enum HealthStatus: String, Codable {
    case Protected
    case Unprotected
    case Stale
    case Unknown
    case Error
}

enum MatchConfidence: String, Codable {
    case Exact
    case ParentPath
    case ChildPath
    case VolumeName
    case Low
    case None
}

struct DockerContainer: Codable, Identifiable {
    var id: String
    let name: String
    let image: String
    let status: String
    let running: Bool
    let volumes: [DockerVolumeMount]
}

struct DockerVolumeMount: Codable {
    let volumeName: String?
    let source: String
    let destination: String
    let mode: String?

    enum CodingKeys: String, CodingKey {
        case volumeName = "volume_name"
        case source
        case destination
        case mode
    }
}

struct DockerVolume: Codable, Identifiable {
    var id: String { name }
    let name: String
    let driver: String
    let mountpoint: String
    let labels: [[String]]
}

struct BackupRepository: Codable, Identifiable {
    let id: String
    let name: String
    let tool: BackupTool
    let location: String
    let passwordEnvKey: String?
    let enabled: Bool
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case tool
        case location
        case passwordEnvKey = "password_env_key"
        case enabled
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct BackupSnapshot: Codable, Identifiable {
    let id: String
    let repositoryId: String
    let tool: BackupTool
    let time: String
    let paths: [String]
    let sizeBytes: UInt64?
    let hostname: String?
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case repositoryId = "repository_id"
        case tool
        case time
        case paths
        case sizeBytes = "size_bytes"
        case hostname
        case tags
    }
}

struct VolumeHealth: Codable, Identifiable {
    var id: String { volume.name }
    let volume: DockerVolume
    let status: HealthStatus
    let confidence: MatchConfidence
    let matchedRepositoryId: String?
    let matchedSnapshotId: String?
    let lastBackupTime: String?
    let backupAgeHours: Double?
    let restoreCommand: String?
    let reason: String

    enum CodingKeys: String, CodingKey {
        case volume
        case status
        case confidence
        case matchedRepositoryId = "matched_repository_id"
        case matchedSnapshotId = "matched_snapshot_id"
        case lastBackupTime = "last_backup_time"
        case backupAgeHours = "backup_age_hours"
        case restoreCommand = "restore_command"
        case reason
    }
}

struct ScanSummary: Codable {
    let scannedAt: String
    let platform: Platform
    let dockerAvailable: Bool
    let dockerRunning: Bool
    let resticAvailable: Bool
    let totalContainers: Int
    let totalVolumes: Int
    let protectedCount: Int
    let unprotectedCount: Int
    let staleCount: Int
    let unknownCount: Int
    let errorCount: Int

    enum CodingKeys: String, CodingKey {
        case scannedAt = "scanned_at"
        case platform
        case dockerAvailable = "docker_available"
        case dockerRunning = "docker_running"
        case resticAvailable = "restic_available"
        case totalContainers = "total_containers"
        case totalVolumes = "total_volumes"
        case protectedCount = "protected_count"
        case unprotectedCount = "unprotected_count"
        case staleCount = "stale_count"
        case unknownCount = "unknown_count"
        case errorCount = "error_count"
    }
}

struct ScanResult: Codable {
    let summary: ScanSummary
    let containers: [DockerContainer]
    let volumes: [DockerVolume]
    let repositories: [BackupRepository]
    let snapshots: [BackupSnapshot]
    let volumeHealth: [VolumeHealth]
    let warnings: [String]
    let errors: [String]

    enum CodingKeys: String, CodingKey {
        case summary
        case containers
        case volumes
        case repositories
        case snapshots
        case volumeHealth = "volume_health"
        case warnings
        case errors
    }
}

struct AppSettings: Codable {
    var staleHours: Int
    var looseMatching: Bool
    var showDockIcon: Bool
    var launchAtLogin: Bool
    var notificationsEnabled: Bool
    var cliPath: String
    var repositories: [BackupRepository]

    enum CodingKeys: String, CodingKey {
        case staleHours = "stale_hours"
        case looseMatching = "loose_matching"
        case showDockIcon = "show_dock_icon"
        case launchAtLogin = "launch_at_login"
        case notificationsEnabled = "notifications_enabled"
        case cliPath = "cli_path"
        case repositories
    }
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case volumes = "Volumes"
    case repositories = "Repositories"
    case reports = "Reports"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .dashboard:
            return "gauge.with.dots.needle.67percent"
        case .volumes:
            return "externaldrive"
        case .repositories:
            return "archivebox"
        case .reports:
            return "doc.text"
        case .settings:
            return "gearshape"
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .dashboard:
            return AppStrings.text(.dashboard, language: language)
        case .volumes:
            return AppStrings.text(.volumes, language: language)
        case .repositories:
            return AppStrings.text(.repositories, language: language)
        case .reports:
            return AppStrings.text(.reports, language: language)
        case .settings:
            return AppStrings.text(.settings, language: language)
        }
    }
}
