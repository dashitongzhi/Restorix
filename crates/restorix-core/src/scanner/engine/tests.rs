mod support;

use super::scan_with_sources;
use crate::models::HealthStatus;
use support::*;

#[test]
fn successful_sources_produce_a_protected_summary() {
    let config = FixedConfig::success(config_with_repository());
    let docker = FakeDocker::running(vec![volume("postgres_data")]);
    let backup = FakeBackup::installed(vec![snapshot("2026-05-15T08:00:00Z")]);
    let clock = FixedClock::at(2026, 5, 15, 10);

    let result = scan_with_sources(&config, &docker, &backup, &clock);

    assert!(result.errors.is_empty());
    assert_eq!(result.summary.total_volumes, 1);
    assert_eq!(result.summary.protected_count, 1);
    assert_eq!(result.volume_health[0].status, HealthStatus::Protected);
}

#[test]
fn partial_source_failures_preserve_volumes_and_mark_health_unknown() {
    let config = FixedConfig::success(config_with_repository());
    let mut docker = FakeDocker::running(vec![volume("postgres_data")]);
    docker.volume_errors = vec!["Docker volume legacy could not be inspected.".to_string()];
    let backup = FakeBackup::failing("repository unavailable");
    let clock = FixedClock::at(2026, 5, 15, 10);

    let result = scan_with_sources(&config, &docker, &backup, &clock);

    assert_eq!(result.volumes.len(), 1);
    assert!(result
        .errors
        .iter()
        .any(|error| error.message.contains("legacy could not be inspected")));
    assert!(result.errors.iter().any(|error| error
        .message
        .contains("Local Restic: Configuration error: repository unavailable")));
    assert_eq!(result.volume_health[0].status, HealthStatus::Unknown);
    assert_eq!(result.summary.unknown_count, 1);
    assert_eq!(result.summary.error_count, 2);
}

#[test]
fn missing_restic_is_a_hard_error_when_a_repository_is_enabled() {
    let config = FixedConfig::success(config_with_repository());
    let docker = FakeDocker::running(vec![volume("redis_data")]);
    let backup = FakeBackup::missing();
    let clock = FixedClock::at(2026, 5, 15, 10);

    let result = scan_with_sources(&config, &docker, &backup, &clock);

    assert!(!result.summary.restic_available);
    assert!(result
        .warnings
        .iter()
        .any(|warning| warning.message.contains("Restic is not installed")));
    assert!(result
        .errors
        .iter()
        .any(|error| error.message.contains("Restic is required")));
    assert_eq!(result.volume_health[0].status, HealthStatus::Unknown);
}

#[test]
fn config_failure_degrades_to_defaults_and_keeps_diagnostics() {
    let config = FixedConfig::failure("invalid configuration");
    let docker = FakeDocker::missing();
    let backup = FakeBackup::installed(Vec::new());
    let clock = FixedClock::at(2026, 5, 15, 10);

    let result = scan_with_sources(&config, &docker, &backup, &clock);

    assert!(result.repositories.is_empty());
    assert!(!result.summary.docker_available);
    assert!(result
        .errors
        .iter()
        .any(|error| error.message.contains("invalid configuration")));
    assert!(result
        .errors
        .iter()
        .any(|error| error.message.contains("Docker is not installed")));
    assert_eq!(result.summary.error_count, 2);
}
