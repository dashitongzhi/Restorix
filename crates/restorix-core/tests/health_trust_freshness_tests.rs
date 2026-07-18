use chrono::{TimeZone, Utc};
use restorix_core::models::{HealthStatus, MatchConfidence};
use restorix_core::scanner::health::{calculate_volume_health, mark_repository_failures_unknown};

mod support;
use support::*;

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
fn snapshot_from_another_host_never_marks_volume_protected() {
    let now = Utc.with_ymd_and_hms(2026, 5, 15, 10, 0, 0).unwrap();
    let mut snapshot = snapshot(
        "snap-other-host",
        "2026-05-15T08:00:00Z",
        "/var/lib/docker/volumes/postgres_data/_data",
    );
    snapshot.hostname = Some("other-host".to_string());

    let health = calculate_volume_health(
        &[volume(
            "postgres_data",
            "/var/lib/docker/volumes/postgres_data/_data",
        )],
        &[repo()],
        &[snapshot],
        72,
        false,
        now,
    );

    assert_eq!(health[0].status, HealthStatus::Unprotected);
    assert!(health[0].matched_snapshot_id.is_none());
}

#[test]
fn repository_without_expected_hostname_is_unknown() {
    let now = Utc.with_ymd_and_hms(2026, 5, 15, 10, 0, 0).unwrap();
    let mut repository = repo();
    repository.expected_hostname = None;

    let health = calculate_volume_health(
        &[volume(
            "postgres_data",
            "/var/lib/docker/volumes/postgres_data/_data",
        )],
        &[repository],
        &[snapshot(
            "snap-1",
            "2026-05-15T08:00:00Z",
            "/var/lib/docker/volumes/postgres_data/_data",
        )],
        72,
        false,
        now,
    );

    assert_eq!(health[0].status, HealthStatus::Unknown);
    assert!(health[0].reason.message.contains("hostname"));
}

#[test]
fn future_snapshot_timestamp_is_not_treated_as_fresh() {
    let now = Utc.with_ymd_and_hms(2026, 5, 15, 10, 0, 0).unwrap();
    let health = calculate_volume_health(
        &[volume(
            "postgres_data",
            "/var/lib/docker/volumes/postgres_data/_data",
        )],
        &[repo()],
        &[snapshot(
            "snap-future",
            "2026-05-15T12:00:00Z",
            "/var/lib/docker/volumes/postgres_data/_data",
        )],
        72,
        false,
        now,
    );

    assert_eq!(health[0].status, HealthStatus::Unknown);
    assert!(health[0].reason.message.contains("future timestamp"));
}

#[test]
fn repository_failure_only_downgrades_unconfirmed_volumes() {
    let now = Utc.with_ymd_and_hms(2026, 5, 15, 10, 0, 0).unwrap();
    let mut health = calculate_volume_health(
        &[
            volume(
                "postgres_data",
                "/var/lib/docker/volumes/postgres_data/_data",
            ),
            volume("redis_data", "/var/lib/docker/volumes/redis_data/_data"),
        ],
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

    mark_repository_failures_unknown(&mut health);

    assert_eq!(health[0].status, HealthStatus::Protected);
    assert_eq!(health[1].status, HealthStatus::Unknown);
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
