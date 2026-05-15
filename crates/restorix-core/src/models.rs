use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Platform {
    MacOS,
    Windows,
    Linux,
    Unknown,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum BackupTool {
    Restic,
    Borg,
    Rclone,
    Unknown,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum HealthStatus {
    Protected,
    Unprotected,
    Stale,
    Unknown,
    Error,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DockerContainer {
    pub id: String,
    pub name: String,
    pub image: String,
    pub status: String,
    pub running: bool,
    pub volumes: Vec<DockerVolumeMount>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DockerVolumeMount {
    pub volume_name: Option<String>,
    pub source: String,
    pub destination: String,
    pub mode: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DockerVolume {
    pub name: String,
    pub driver: String,
    pub mountpoint: String,
    pub labels: Vec<(String, String)>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackupRepository {
    pub id: String,
    pub name: String,
    pub tool: BackupTool,
    pub location: String,
    pub password_env_key: Option<String>,
    pub enabled: bool,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackupSnapshot {
    pub id: String,
    pub repository_id: String,
    pub tool: BackupTool,
    pub time: String,
    pub paths: Vec<String>,
    pub size_bytes: Option<u64>,
    pub hostname: Option<String>,
    pub tags: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord)]
pub enum MatchConfidence {
    Exact,
    ParentPath,
    ChildPath,
    VolumeName,
    Low,
    None,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VolumeHealth {
    pub volume: DockerVolume,
    pub status: HealthStatus,
    pub confidence: MatchConfidence,
    pub matched_repository_id: Option<String>,
    pub matched_snapshot_id: Option<String>,
    pub last_backup_time: Option<String>,
    pub backup_age_hours: Option<f64>,
    pub restore_command: Option<String>,
    pub reason: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScanSummary {
    pub scanned_at: String,
    pub platform: Platform,
    pub docker_available: bool,
    pub docker_running: bool,
    pub restic_available: bool,
    pub total_containers: usize,
    pub total_volumes: usize,
    pub protected_count: usize,
    pub unprotected_count: usize,
    pub stale_count: usize,
    pub unknown_count: usize,
    pub error_count: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScanResult {
    pub summary: ScanSummary,
    pub containers: Vec<DockerContainer>,
    pub volumes: Vec<DockerVolume>,
    pub repositories: Vec<BackupRepository>,
    pub snapshots: Vec<BackupSnapshot>,
    pub volume_health: Vec<VolumeHealth>,
    pub warnings: Vec<String>,
    pub errors: Vec<String>,
}
