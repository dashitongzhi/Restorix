import Foundation

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
    let reason: Diagnostic

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
    let warnings: [Diagnostic]
    let errors: [Diagnostic]

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

