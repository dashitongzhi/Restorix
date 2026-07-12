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

    let trusted_snapshots = snapshots
        .iter()
        .filter(|snapshot| snapshot_has_expected_hostname(snapshot, repositories))
        .cloned()
        .collect::<Vec<_>>();

    let Some(snapshot_match) = best_snapshot_match(volume, &trusted_snapshots) else {
        if repositories
            .iter()
            .any(|repository| repository.enabled && missing_expected_hostname(repository))
        {
            return unknown(
                volume,
                "An enabled repository has no expected snapshot hostname, so Restorix cannot prove host-specific backup coverage.",
            );
        }
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
        let reason = match snapshot_match.confidence {
            MatchConfidence::ChildPath => {
                "A snapshot only covers a child path inside this Docker volume, so full-volume protection is unknown."
            }
            MatchConfidence::VolumeName => {
                "Only a volume-name match was found. Enable loose matching to treat this as protected."
            }
            _ => "Snapshot coverage is not reliable enough to determine full-volume protection.",
        };
        return VolumeHealth {
            volume: volume.clone(),
            status: HealthStatus::Unknown,
            confidence: snapshot_match.confidence,
            matched_repository_id: Some(snapshot.repository_id),
            matched_snapshot_id: Some(snapshot.id),
            last_backup_time: Some(snapshot.time),
            backup_age_hours: age_hours,
            restore_command,
            reason: reason.to_string(),
        };
    }

    match age_hours {
        Some(age) if age < 0.0 => VolumeHealth {
            volume: volume.clone(),
            status: HealthStatus::Unknown,
            confidence: snapshot_match.confidence,
            matched_repository_id: Some(snapshot.repository_id),
            matched_snapshot_id: Some(snapshot.id),
            last_backup_time: Some(snapshot.time),
            backup_age_hours: Some(age),
            restore_command,
            reason: "A matching snapshot has a future timestamp, so backup freshness is unknown."
                .to_string(),
        },
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

pub fn mark_repository_failures_unknown(volume_health: &mut [VolumeHealth]) {
    for health in volume_health
        .iter_mut()
        .filter(|health| health.status == HealthStatus::Unprotected)
    {
        health.status = HealthStatus::Unknown;
        health.reason = "At least one repository scan failed, so Restorix cannot confirm this volume is unprotected."
            .to_string();
    }
}

fn snapshot_has_expected_hostname(
    snapshot: &BackupSnapshot,
    repositories: &[BackupRepository],
) -> bool {
    repositories
        .iter()
        .find(|repository| repository.id == snapshot.repository_id && repository.enabled)
        .and_then(|repository| repository.expected_hostname.as_deref())
        .is_some_and(|expected| snapshot.hostname.as_deref() == Some(expected))
}

fn missing_expected_hostname(repository: &BackupRepository) -> bool {
    repository
        .expected_hostname
        .as_deref()
        .is_none_or(|hostname| hostname.trim().is_empty())
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
    let password_assignment = repo
        .password_env_key
        .as_deref()
        .filter(|key| is_valid_environment_key(key))
        .map(|key| {
            format!(" RESTIC_PASSWORD=\"${{{key}:?Set {key} before running this command}}\"")
        })
        .unwrap_or_default();

    format!(
        "RESTIC_REPOSITORY={}{} restic restore {} --target {} --include {}",
        shell_quote(&repo.location),
        password_assignment,
        shell_quote(snapshot_id),
        shell_quote("./restorix-restore-test"),
        shell_quote(include_path)
    )
}

fn snapshot_age_hours(time: &str, now: DateTime<Utc>) -> Option<f64> {
    let parsed = DateTime::parse_from_rfc3339(time).ok()?.with_timezone(&Utc);
    let duration = now.signed_duration_since(parsed);
    Some(duration.num_minutes() as f64 / 60.0)
}

fn shell_quote(value: &str) -> String {
    format!("'{}'", value.replace('\'', "'\"'\"'"))
}

fn is_valid_environment_key(key: &str) -> bool {
    let mut characters = key.chars();
    matches!(characters.next(), Some(character) if character == '_' || character.is_ascii_alphabetic())
        && characters.all(|character| character == '_' || character.is_ascii_alphanumeric())
}
