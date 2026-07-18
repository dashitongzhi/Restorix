use chrono::{TimeZone, Utc};
use restorix_core::models::{HealthStatus, MatchConfidence};
use restorix_core::scanner::health::calculate_volume_health;
use restorix_core::scanner::matcher::match_path;

mod support;
use support::*;

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
