use chrono::{TimeZone, Utc};
use restorix_core::models::{
    BackupRepository, BackupSnapshot, BackupTool, DockerVolume, HealthStatus, MatchConfidence,
};
use restorix_core::scanner::health::{build_restore_command, calculate_volume_health};
use restorix_core::scanner::matcher::match_path;

#[test]
fn path_matching_prefers_exact_parent_and_child_matches() {
    let volume = volume(
        "postgres_data",
        "/var/lib/docker/volumes/postgres_data/_data",
    );

    assert_eq!(
        match_path(&volume, "/var/lib/docker/volumes/postgres_data/_data"),
        MatchConfidence::Exact
    );
    assert_eq!(
        match_path(&volume, "/var/lib/docker/volumes/postgres_data"),
        MatchConfidence::ParentPath
    );
    assert_eq!(
        match_path(&volume, "/var/lib/docker/volumes/postgres_data/_data/base"),
        MatchConfidence::ChildPath
    );
    assert_eq!(
        match_path(&volume, "/Users/me/backups/postgres_data"),
        MatchConfidence::VolumeName
    );
}

#[test]
fn recent_reliable_snapshot_marks_volume_protected() {
    let now = Utc.with_ymd_and_hms(2026, 5, 15, 10, 0, 0).unwrap();
    let health = calculate_volume_health(
        &[volume(
            "postgres_data",
            "/var/lib/docker/volumes/postgres_data/_data",
        )],
        &[repo()],
        &[snapshot(
            "snap-1",
            "2026-05-15T08:00:00Z",
            "/var/lib/docker/volumes/postgres_data/_data",
        )],
        72,
        false,
        now,
    );

    assert_eq!(health[0].status, HealthStatus::Protected);
    assert_eq!(health[0].confidence, MatchConfidence::Exact);
    assert!(health[0]
        .restore_command
        .as_ref()
        .unwrap()
        .contains("restic restore 'snap-1'"));
}

#[test]
fn old_reliable_snapshot_marks_volume_stale() {
    let now = Utc.with_ymd_and_hms(2026, 5, 15, 10, 0, 0).unwrap();
    let health = calculate_volume_health(
        &[volume("n8n_data", "/var/lib/docker/volumes/n8n_data/_data")],
        &[repo()],
        &[snapshot(
            "snap-1",
            "2026-05-10T00:00:00Z",
            "/var/lib/docker/volumes/n8n_data",
        )],
        72,
        false,
        now,
    );

    assert_eq!(health[0].status, HealthStatus::Stale);
    assert_eq!(health[0].confidence, MatchConfidence::ParentPath);
}

#[test]
fn newer_reliable_snapshot_wins_over_older_exact_match() {
    let now = Utc.with_ymd_and_hms(2026, 5, 15, 10, 0, 0).unwrap();
    let health = calculate_volume_health(
        &[volume(
            "postgres_data",
            "/var/lib/docker/volumes/postgres_data/_data",
        )],
        &[repo()],
        &[
            snapshot(
                "old-exact",
                "2026-05-10T00:00:00Z",
                "/var/lib/docker/volumes/postgres_data/_data",
            ),
            snapshot(
                "new-parent",
                "2026-05-15T08:00:00Z",
                "/var/lib/docker/volumes/postgres_data",
            ),
        ],
        72,
        false,
        now,
    );

    assert_eq!(health[0].status, HealthStatus::Protected);
    assert_eq!(health[0].matched_snapshot_id.as_deref(), Some("new-parent"));
}

#[test]
fn missing_match_marks_volume_unprotected() {
    let now = Utc.with_ymd_and_hms(2026, 5, 15, 10, 0, 0).unwrap();
    let health = calculate_volume_health(
        &[volume(
            "redis_data",
            "/var/lib/docker/volumes/redis_data/_data",
        )],
        &[repo()],
        &[snapshot(
            "snap-1",
            "2026-05-15T08:00:00Z",
            "/var/lib/docker/volumes/postgres_data/_data",
        )],
        72,
        false,
        now,
    );

    assert_eq!(health[0].status, HealthStatus::Unprotected);
}

#[test]
fn child_only_snapshot_marks_volume_unknown() {
    let now = Utc.with_ymd_and_hms(2026, 5, 15, 10, 0, 0).unwrap();
    let health = calculate_volume_health(
        &[volume(
            "postgres_data",
            "/var/lib/docker/volumes/postgres_data/_data",
        )],
        &[repo()],
        &[snapshot(
            "snap-child-only",
            "2026-05-15T08:00:00Z",
            "/var/lib/docker/volumes/postgres_data/_data/base/demo.txt",
        )],
        72,
        false,
        now,
    );

    assert_eq!(health[0].status, HealthStatus::Unknown);
    assert_eq!(health[0].confidence, MatchConfidence::ChildPath);
}

#[test]
fn restore_command_quotes_untrusted_values_and_maps_password_environment() {
    let mut repository = repo();
    repository.location = "s3:bucket/$(printf injected) 'quoted'".to_string();
    repository.password_env_key = Some("RESTIC_BACKUP_PASSWORD".to_string());

    let command = build_restore_command(
        &repository,
        "snapshot; printf injected",
        "/data/`printf injected`/volume",
    );

    assert_eq!(
        command,
        "RESTIC_REPOSITORY='s3:bucket/$(printf injected) '\"'\"'quoted'\"'\"'' RESTIC_PASSWORD=\"${RESTIC_BACKUP_PASSWORD:?Set RESTIC_BACKUP_PASSWORD before running this command}\" restic restore 'snapshot; printf injected' --target './restorix-restore-test' --include '/data/`printf injected`/volume'"
    );
}

#[test]
fn restore_command_ignores_invalid_password_environment_names() {
    let mut repository = repo();
    repository.password_env_key = Some("RESTIC_PASSWORD; printf injected".to_string());

    let command = build_restore_command(&repository, "snapshot", "/data/volume");

    assert!(!command.contains("RESTIC_PASSWORD=\"${RESTIC_PASSWORD;"));
    assert_eq!(
        command,
        "RESTIC_REPOSITORY='/tmp/restic' restic restore 'snapshot' --target './restorix-restore-test' --include '/data/volume'"
    );
}

#[test]
fn volume_name_match_is_unknown_without_loose_matching() {
    let now = Utc.with_ymd_and_hms(2026, 5, 15, 10, 0, 0).unwrap();
    let health = calculate_volume_health(
        &[volume(
            "postgres_data",
            "/var/lib/docker/volumes/postgres_data/_data",
        )],
        &[repo()],
        &[snapshot(
            "snap-1",
            "2026-05-15T08:00:00Z",
            "/Users/me/backups/postgres_data",
        )],
        72,
        false,
        now,
    );

    assert_eq!(health[0].status, HealthStatus::Unknown);
    assert_eq!(health[0].confidence, MatchConfidence::VolumeName);
}

fn volume(name: &str, mountpoint: &str) -> DockerVolume {
    DockerVolume {
        name: name.to_string(),
        driver: "local".to_string(),
        mountpoint: mountpoint.to_string(),
        labels: Vec::new(),
    }
}

fn repo() -> BackupRepository {
    BackupRepository {
        id: "repo-1".to_string(),
        name: "Local Restic".to_string(),
        tool: BackupTool::Restic,
        location: "/tmp/restic".to_string(),
        password_env_key: Some("RESTIC_PASSWORD".to_string()),
        enabled: true,
        created_at: "2026-05-15T00:00:00Z".to_string(),
        updated_at: "2026-05-15T00:00:00Z".to_string(),
    }
}

fn snapshot(id: &str, time: &str, path: &str) -> BackupSnapshot {
    BackupSnapshot {
        id: id.to_string(),
        repository_id: "repo-1".to_string(),
        tool: BackupTool::Restic,
        time: time.to_string(),
        paths: vec![path.to_string()],
        size_bytes: None,
        hostname: Some("homelab".to_string()),
        tags: vec!["docker".to_string()],
    }
}
