import Foundation

enum HealthStatus: String, Codable {
    case Protected
    case Unprotected
    case Stale
    case Unknown
    case Error

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: value) ?? .Unknown
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
enum MatchConfidence: String, Codable {
    case Exact
    case ParentPath
    case ChildPath
    case VolumeName
    case Low
    case None

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: value) ?? .None
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
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
    let schemaVersion: Int
    let summary: ScanSummary
    let containers: [DockerContainer]
    let volumes: [DockerVolume]
    let repositories: [BackupRepository]
    let snapshots: [BackupSnapshot]
    let volumeHealth: [VolumeHealth]
    let warnings: [Diagnostic]
    let errors: [Diagnostic]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case summary
        case containers
        case volumes
        case repositories
        case snapshots
        case volumeHealth = "volume_health"
        case warnings
        case errors
    }

    init(
        schemaVersion: Int = 1,
        summary: ScanSummary,
        containers: [DockerContainer],
        volumes: [DockerVolume],
        repositories: [BackupRepository],
        snapshots: [BackupSnapshot],
        volumeHealth: [VolumeHealth],
        warnings: [Diagnostic],
        errors: [Diagnostic]
    ) {
        self.schemaVersion = schemaVersion
        self.summary = summary
        self.containers = containers
        self.volumes = volumes
        self.repositories = repositories
        self.snapshots = snapshots
        self.volumeHealth = volumeHealth
        self.warnings = warnings
        self.errors = errors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        summary = try container.decode(ScanSummary.self, forKey: .summary)
        containers = try container.decode([DockerContainer].self, forKey: .containers)
        volumes = try container.decode([DockerVolume].self, forKey: .volumes)
        repositories = try container.decode([BackupRepository].self, forKey: .repositories)
        snapshots = try container.decode([BackupSnapshot].self, forKey: .snapshots)
        volumeHealth = try container.decode([VolumeHealth].self, forKey: .volumeHealth)
        warnings = try container.decode([Diagnostic].self, forKey: .warnings)
        errors = try container.decode([Diagnostic].self, forKey: .errors)
    }
}
