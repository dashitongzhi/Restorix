use crate::models::{
    BackupRepository, BackupSnapshot, DockerVolume, HealthStatus, MatchConfidence, VolumeHealth,
};
use crate::scanner::matcher::{best_snapshot_match, is_reliable_match};
use chrono::{DateTime, Utc};

pub fn calculate_volume_health(
    volumes: &[DockerVolume],
    repositories: &[BackupRepository],
    snapshots: &[BackupSnapshot],
    stale_hours: u64,
    loose_matching: bool,
    now: DateTime<Utc>,
) -> Vec<VolumeHealth> {
    volumes
        .iter()
        .map(|volume| {
            calculate_one_volume_health(
                volume,
                repositories,
                snapshots,
                stale_hours,
                loose_matching,
                now,
            )
        })
        .collect()
}

fn calculate_one_volume_health(
    volume: &DockerVolume,
    repositories: &[BackupRepository],
    snapshots: &[BackupSnapshot],
    stale_hours: u64,
    loose_matching: bool,
    now: DateTime<Utc>,
) -> VolumeHealth {
    if volume.mountpoint.trim().is_empty() {
        return unknown(
            volume,
            "Docker metadata is incomplete: volume mountpoint is empty.",
        );
    }

    if repositories.iter().all(|repo| !repo.enabled) {
        return unknown(volume, "No enabled backup repositories are configured.");
    }

    let Some(snapshot_match) = best_snapshot_match(volume, snapshots) else {
        return VolumeHealth {
            volume: volume.clone(),
            status: HealthStatus::Unprotected,
            confidence: MatchConfidence::None,
            matched_repository_id: None,
            matched_snapshot_id: None,
            last_backup_time: None,
            backup_age_hours: None,
            restore_command: None,
            reason: "No reliable snapshot path matched this Docker volume mountpoint.".to_string(),
        };
    };

    let snapshot = snapshot_match.snapshot;
    let age_hours = snapshot_age_hours(&snapshot.time, now);
    let reliable = is_reliable_match(&snapshot_match.confidence, loose_matching);
    let repo = repositories
        .iter()
        .find(|repo| repo.id == snapshot.repository_id);
    let restore_command =
        repo.map(|repo| build_restore_command(repo, &snapshot.id, &volume.mountpoint));

    if !reliable {
        return VolumeHealth {
            volume: volume.clone(),
            status: HealthStatus::Unknown,
            confidence: snapshot_match.confidence,
            matched_repository_id: Some(snapshot.repository_id),
            matched_snapshot_id: Some(snapshot.id),
            last_backup_time: Some(snapshot.time),
            backup_age_hours: age_hours,
            restore_command,
            reason: "Only a volume-name match was found. Enable loose matching to treat this as protected.".to_string(),
        };
    }

    match age_hours {
        Some(age) if age > stale_hours as f64 => VolumeHealth {
            volume: volume.clone(),
            status: HealthStatus::Stale,
            confidence: snapshot_match.confidence,
            matched_repository_id: Some(snapshot.repository_id),
            matched_snapshot_id: Some(snapshot.id),
            last_backup_time: Some(snapshot.time),
            backup_age_hours: Some(age),
            restore_command,
            reason: format!(
                "Latest matching snapshot is older than the stale threshold ({stale_hours} hours)."
            ),
        },
        Some(age) => VolumeHealth {
            volume: volume.clone(),
            status: HealthStatus::Protected,
            confidence: snapshot_match.confidence,
            matched_repository_id: Some(snapshot.repository_id),
            matched_snapshot_id: Some(snapshot.id),
            last_backup_time: Some(snapshot.time),
            backup_age_hours: Some(age),
            restore_command,
            reason: "A recent restic snapshot matches this Docker volume mountpoint.".to_string(),
        },
        None => VolumeHealth {
            volume: volume.clone(),
            status: HealthStatus::Unknown,
            confidence: snapshot_match.confidence,
            matched_repository_id: Some(snapshot.repository_id),
            matched_snapshot_id: Some(snapshot.id),
            last_backup_time: Some(snapshot.time),
            backup_age_hours: None,
            restore_command,
            reason: "A matching snapshot was found, but its timestamp could not be parsed."
                .to_string(),
        },
    }
}

fn unknown(volume: &DockerVolume, reason: &str) -> VolumeHealth {
    VolumeHealth {
        volume: volume.clone(),
        status: HealthStatus::Unknown,
        confidence: MatchConfidence::None,
        matched_repository_id: None,
        matched_snapshot_id: None,
        last_backup_time: None,
        backup_age_hours: None,
        restore_command: None,
        reason: reason.to_string(),
    }
}

pub fn build_restore_command(
    repo: &BackupRepository,
    snapshot_id: &str,
    include_path: &str,
) -> String {
    format!(
        "RESTIC_REPOSITORY=\"{}\" restic restore {} --target ./restorix-restore-test --include \"{}\"",
        shell_escape(&repo.location),
        shell_escape(snapshot_id),
        shell_escape(include_path)
    )
}

fn snapshot_age_hours(time: &str, now: DateTime<Utc>) -> Option<f64> {
    let parsed = DateTime::parse_from_rfc3339(time).ok()?.with_timezone(&Utc);
    let duration = now.signed_duration_since(parsed);
    Some(duration.num_minutes() as f64 / 60.0)
}

fn shell_escape(value: &str) -> String {
    value.replace('\\', "\\\\").replace('"', "\\\"")
}
