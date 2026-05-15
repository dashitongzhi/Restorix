use crate::docker::client::DockerClient;
use crate::models::{
    HealthStatus, MatchConfidence, Platform, ScanResult, ScanSummary, VolumeHealth,
};
use crate::restic::client::ResticClient;
use crate::scanner::health::calculate_volume_health;
use crate::storage::config::ConfigStore;
use chrono::Utc;

pub fn scan(config_store: &ConfigStore) -> ScanResult {
    let now = Utc::now();
    let mut warnings = Vec::new();
    let mut errors = Vec::new();
    let config = match config_store.load() {
        Ok(config) => config,
        Err(error) => {
            errors.push(error.to_string());
            Default::default()
        }
    };

    let docker = DockerClient::new();
    let restic = ResticClient::new();
    let docker_status = docker.check();
    let restic_status = restic.check();

    if let Some(message) = &docker_status.message {
        errors.push(message.clone());
    }
    if let Some(message) = &restic_status.message {
        warnings.push(message.clone());
    }

    let containers = if docker_status.running {
        match docker.scan_containers() {
            Ok(containers) => containers,
            Err(error) => {
                errors.push(error.to_string());
                Vec::new()
            }
        }
    } else {
        Vec::new()
    };

    let volumes = if docker_status.running {
        match docker.scan_volumes() {
            Ok(volumes) => volumes,
            Err(error) => {
                errors.push(error.to_string());
                Vec::new()
            }
        }
    } else {
        Vec::new()
    };

    let repositories = config.repositories.clone();
    add_context_warnings(&mut warnings, &volumes, &repositories);
    let mut snapshots = Vec::new();

    let mut repository_scan_failed = false;

    if restic_status.installed {
        for repo in repositories.iter().filter(|repo| repo.enabled) {
            match restic.snapshots(repo) {
                Ok(mut repo_snapshots) => snapshots.append(&mut repo_snapshots),
                Err(error) => {
                    repository_scan_failed = true;
                    errors.push(format!("{}: {}", repo.name, error));
                }
            }
        }
    } else if repositories.iter().any(|repo| repo.enabled) {
        repository_scan_failed = true;
        errors.push(
            "Restic is required by at least one enabled repository but is not installed."
                .to_string(),
        );
    }

    let volume_health = if repository_scan_failed && snapshots.is_empty() && !volumes.is_empty() {
        volumes
            .iter()
            .map(|volume| VolumeHealth {
                volume: volume.clone(),
                status: HealthStatus::Error,
                confidence: MatchConfidence::None,
                matched_repository_id: None,
                matched_snapshot_id: None,
                last_backup_time: None,
                backup_age_hours: None,
                restore_command: None,
                reason: "Repository scan failed, so Restorix cannot determine backup health for this volume."
                    .to_string(),
            })
            .collect()
    } else {
        calculate_volume_health(
            &volumes,
            &repositories,
            &snapshots,
            config.stale_hours,
            config.loose_matching,
            now,
        )
    };

    let summary = build_summary(
        now.to_rfc3339(),
        docker_status.installed,
        docker_status.running,
        restic_status.installed,
        containers.len(),
        volumes.len(),
        &volume_health,
    );

    ScanResult {
        summary,
        containers,
        volumes,
        repositories,
        snapshots,
        volume_health,
        warnings,
        errors,
    }
}

fn build_summary(
    scanned_at: String,
    docker_available: bool,
    docker_running: bool,
    restic_available: bool,
    total_containers: usize,
    total_volumes: usize,
    volume_health: &[crate::models::VolumeHealth],
) -> ScanSummary {
    ScanSummary {
        scanned_at,
        platform: current_platform(),
        docker_available,
        docker_running,
        restic_available,
        total_containers,
        total_volumes,
        protected_count: count_status(volume_health, HealthStatus::Protected),
        unprotected_count: count_status(volume_health, HealthStatus::Unprotected),
        stale_count: count_status(volume_health, HealthStatus::Stale),
        unknown_count: count_status(volume_health, HealthStatus::Unknown),
        error_count: count_status(volume_health, HealthStatus::Error),
    }
}

fn add_context_warnings(
    warnings: &mut Vec<String>,
    volumes: &[crate::models::DockerVolume],
    repositories: &[crate::models::BackupRepository],
) {
    if !volumes.is_empty() && repositories.iter().all(|repo| !repo.enabled) {
        warnings.push(
            "No enabled backup repositories are configured, so Restorix can list Docker volumes but cannot verify backups."
                .to_string(),
        );
    }

    let stateful_names = volumes
        .iter()
        .filter(|volume| looks_stateful_or_database(&volume.name))
        .map(|volume| volume.name.clone())
        .collect::<Vec<_>>();

    if !stateful_names.is_empty() {
        warnings.push(format!(
            "These volumes look stateful or database-backed: {}. File-level snapshots may still need app-aware dumps or a stopped container for consistent restores.",
            stateful_names.join(", ")
        ));
    }
}

fn looks_stateful_or_database(name: &str) -> bool {
    let name = name.to_ascii_lowercase();
    [
        "pgdata",
        "postgres",
        "postgresql",
        "mysql",
        "mariadb",
        "mongo",
        "redis",
        "minio",
        "database",
        "db",
    ]
    .iter()
    .any(|token| name.contains(token))
}

fn count_status(volume_health: &[crate::models::VolumeHealth], status: HealthStatus) -> usize {
    volume_health
        .iter()
        .filter(|health| health.status == status)
        .count()
}

fn current_platform() -> Platform {
    if cfg!(target_os = "macos") {
        Platform::MacOS
    } else if cfg!(target_os = "linux") {
        Platform::Linux
    } else if cfg!(target_os = "windows") {
        Platform::Windows
    } else {
        Platform::Unknown
    }
}
