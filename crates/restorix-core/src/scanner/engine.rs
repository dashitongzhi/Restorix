use crate::diagnostic::{Diagnostic, DiagnosticCode};
use crate::docker::client::DockerClient;
use crate::models::{HealthStatus, Platform, ScanResult, ScanSummary, VolumeHealth};
use crate::restic::client::ResticClient;
use crate::scanner::health::{calculate_volume_health, mark_repository_failures_unknown};
use crate::scanner::sources::{BackupSource, Clock, ConfigSource, DockerSource, SystemClock};
use crate::storage::config::ConfigStore;

pub fn scan(config_store: &ConfigStore) -> ScanResult {
    scan_with_sources(
        config_store,
        &DockerClient::new(),
        &ResticClient::new(),
        &SystemClock,
    )
}

fn scan_with_sources(
    config_source: &impl ConfigSource,
    docker: &impl DockerSource,
    backup: &impl BackupSource,
    clock: &impl Clock,
) -> ScanResult {
    let now = clock.now();
    let mut warnings = Vec::new();
    let mut errors = Vec::new();
    let config = match config_source.load_config() {
        Ok(config) => config,
        Err(error) => {
            let detail = error.to_string();
            errors.push(Diagnostic::with_detail(
                DiagnosticCode::ConfigLoadFailed,
                detail.clone(),
                detail,
            ));
            Default::default()
        }
    };

    let docker_status = docker.status();
    let restic_status = backup.status();

    if let Some(message) = &docker_status.message {
        errors.push(Diagnostic::with_detail(
            DiagnosticCode::DockerUnavailable,
            message.clone(),
            message.clone(),
        ));
    }
    if let Some(message) = &restic_status.message {
        warnings.push(Diagnostic::with_detail(
            DiagnosticCode::ResticUnavailable,
            message.clone(),
            message.clone(),
        ));
    }

    let containers = if docker_status.running {
        match docker.containers() {
            Ok(containers) => containers,
            Err(error) => {
                let detail = error.to_string();
                errors.push(Diagnostic::with_detail(
                    DiagnosticCode::DockerContainerScanFailed,
                    detail.clone(),
                    detail,
                ));
                Vec::new()
            }
        }
    } else {
        Vec::new()
    };

    let volumes = if docker_status.running {
        match docker.volumes() {
            Ok(scan) => {
                errors.extend(scan.errors.into_iter().map(|message| {
                    Diagnostic::with_detail(
                        DiagnosticCode::DockerVolumeInspectFailed,
                        message.clone(),
                        message,
                    )
                }));
                scan.volumes
            }
            Err(error) => {
                let detail = error.to_string();
                errors.push(Diagnostic::with_detail(
                    DiagnosticCode::DockerVolumeScanFailed,
                    detail.clone(),
                    detail,
                ));
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
            match backup.snapshots(repo) {
                Ok(mut repo_snapshots) => snapshots.append(&mut repo_snapshots),
                Err(error) => {
                    repository_scan_failed = true;
                    let detail = error.to_string();
                    errors.push(Diagnostic::with_repository(
                        DiagnosticCode::RepositoryScanFailed,
                        format!("{}: {}", repo.name, detail),
                        repo.name.clone(),
                        detail,
                    ));
                }
            }
        }
    } else if repositories.iter().any(|repo| repo.enabled) {
        repository_scan_failed = true;
        errors.push(Diagnostic::simple(
            DiagnosticCode::ResticRequiredMissing,
            "Restic is required by at least one enabled repository but is not installed.",
        ));
    }

    let mut volume_health = calculate_volume_health(
        &volumes,
        &repositories,
        &snapshots,
        config.stale_hours,
        config.loose_matching,
        now,
    );
    if repository_scan_failed {
        mark_repository_failures_unknown(&mut volume_health);
    }

    let summary = build_summary(ScanSummaryInput {
        scanned_at: now.to_rfc3339(),
        docker_available: docker_status.installed,
        docker_running: docker_status.running,
        restic_available: restic_status.installed,
        total_containers: containers.len(),
        total_volumes: volumes.len(),
        volume_health: &volume_health,
        global_error_count: errors.len(),
    });

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

#[cfg(test)]
mod tests;

struct ScanSummaryInput<'a> {
    scanned_at: String,
    docker_available: bool,
    docker_running: bool,
    restic_available: bool,
    total_containers: usize,
    total_volumes: usize,
    volume_health: &'a [VolumeHealth],
    global_error_count: usize,
}

fn build_summary(input: ScanSummaryInput<'_>) -> ScanSummary {
    ScanSummary {
        scanned_at: input.scanned_at,
        platform: current_platform(),
        docker_available: input.docker_available,
        docker_running: input.docker_running,
        restic_available: input.restic_available,
        total_containers: input.total_containers,
        total_volumes: input.total_volumes,
        protected_count: count_status(input.volume_health, HealthStatus::Protected),
        unprotected_count: count_status(input.volume_health, HealthStatus::Unprotected),
        stale_count: count_status(input.volume_health, HealthStatus::Stale),
        unknown_count: count_status(input.volume_health, HealthStatus::Unknown),
        error_count: input.global_error_count
            + count_status(input.volume_health, HealthStatus::Error),
    }
}

fn add_context_warnings(
    warnings: &mut Vec<Diagnostic>,
    volumes: &[crate::models::DockerVolume],
    repositories: &[crate::models::BackupRepository],
) {
    if !volumes.is_empty() && repositories.iter().all(|repo| !repo.enabled) {
        warnings.push(Diagnostic::simple(
            DiagnosticCode::BackupVerificationUnconfigured,
            "No enabled backup repositories are configured, so Restorix can list Docker volumes but cannot verify backups.",
        ));
    }

    let stateful_names = volumes
        .iter()
        .filter(|volume| looks_stateful_or_database(&volume.name))
        .map(|volume| volume.name.clone())
        .collect::<Vec<_>>();

    if !stateful_names.is_empty() {
        warnings.push(Diagnostic::with_volumes(
            DiagnosticCode::StatefulVolumes,
            format!(
                "These volumes look stateful or database-backed: {}. File-level snapshots may still need app-aware dumps or a stopped container for consistent restores.",
                stateful_names.join(", ")
            ),
            stateful_names,
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
