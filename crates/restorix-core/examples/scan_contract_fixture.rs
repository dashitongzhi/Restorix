use restorix_core::diagnostic::{Diagnostic, DiagnosticCode};
use restorix_core::models::{
    BackupRepository, BackupSnapshot, BackupTool, DockerContainer, DockerVolume, DockerVolumeMount,
    HealthStatus, MatchConfidence, Platform, ScanResult, ScanSummary, VolumeHealth,
    SCAN_RESULT_SCHEMA_VERSION,
};

fn main() {
    let volume = DockerVolume {
        name: "postgres_data".to_string(),
        driver: "local".to_string(),
        mountpoint: "/var/lib/docker/volumes/postgres_data/_data".to_string(),
        labels: vec![("service".to_string(), "postgres".to_string())],
    };
    let repository = BackupRepository {
        id: "repo-1".to_string(),
        name: "Contract Restic".to_string(),
        tool: BackupTool::Restic,
        location: "/tmp/restic".to_string(),
        password_env_key: Some("RESTIC_PASSWORD".to_string()),
        expected_hostname: Some("fixture-host".to_string()),
        enabled: true,
        created_at: "2026-07-27T00:00:00Z".to_string(),
        updated_at: "2026-07-27T00:00:00Z".to_string(),
    };
    let snapshot = BackupSnapshot {
        id: "snapshot-1".to_string(),
        repository_id: repository.id.clone(),
        tool: BackupTool::Restic,
        time: "2026-07-27T00:00:00Z".to_string(),
        paths: vec![volume.mountpoint.clone()],
        size_bytes: Some(1024),
        hostname: Some("fixture-host".to_string()),
        tags: vec!["contract".to_string()],
    };
    let result = ScanResult {
        schema_version: SCAN_RESULT_SCHEMA_VERSION,
        summary: ScanSummary {
            scanned_at: "2026-07-27T01:00:00Z".to_string(),
            platform: Platform::MacOS,
            docker_available: true,
            docker_running: true,
            restic_available: true,
            total_containers: 1,
            total_volumes: 1,
            protected_count: 1,
            unprotected_count: 0,
            stale_count: 0,
            unknown_count: 0,
            error_count: 0,
        },
        containers: vec![DockerContainer {
            id: "container-1".to_string(),
            name: "postgres".to_string(),
            image: "postgres:latest".to_string(),
            status: "Up".to_string(),
            running: true,
            volumes: vec![DockerVolumeMount {
                volume_name: Some(volume.name.clone()),
                source: volume.mountpoint.clone(),
                destination: "/var/lib/postgresql/data".to_string(),
                mode: Some("rw".to_string()),
            }],
        }],
        volumes: vec![volume.clone()],
        repositories: vec![repository],
        snapshots: vec![snapshot],
        volume_health: vec![VolumeHealth {
            volume,
            status: HealthStatus::Protected,
            confidence: MatchConfidence::Exact,
            matched_repository_id: Some("repo-1".to_string()),
            matched_snapshot_id: Some("snapshot-1".to_string()),
            last_backup_time: Some("2026-07-27T00:00:00Z".to_string()),
            backup_age_hours: Some(1.0),
            restore_command: Some("restic restore 'snapshot-1'".to_string()),
            reason: Diagnostic::simple(
                DiagnosticCode::RecentSnapshot,
                "A recent restic snapshot matches this Docker volume mountpoint.",
            ),
        }],
        warnings: Vec::new(),
        errors: Vec::new(),
    };

    println!(
        "{}",
        serde_json::to_string(&result).expect("scan contract fixture must serialize")
    );
}
