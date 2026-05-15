use restorix_core::docker::parser::{
    parse_container_inspect, parse_container_rows, parse_volume_inspect, parse_volume_rows,
};
use restorix_core::models::{BackupRepository, BackupTool};
use restorix_core::restic::parser::parse_snapshots;

#[test]
fn parses_docker_ps_json_lines() {
    let rows = parse_container_rows(include_str!("fixtures/docker_ps.jsonl")).unwrap();
    assert_eq!(rows.len(), 2);
    assert_eq!(rows[0].id, "abc123");
    assert_eq!(rows[0].name, "postgres");
    assert_eq!(rows[1].status, "Exited (0) 1 hour ago");
}

#[test]
fn parses_docker_volume_ls_json_lines() {
    let rows = parse_volume_rows(include_str!("fixtures/docker_volume_ls.jsonl")).unwrap();
    assert_eq!(rows.len(), 2);
    assert_eq!(rows[0].name, "postgres_data");
}

#[test]
fn parses_docker_container_mounts() {
    let mounts =
        parse_container_inspect(include_str!("fixtures/docker_container_inspect.json")).unwrap();
    assert_eq!(mounts.len(), 1);
    assert_eq!(mounts[0].volume_name.as_deref(), Some("postgres_data"));
    assert_eq!(mounts[0].destination, "/var/lib/postgresql/data");
}

#[test]
fn parses_docker_volume_inspect() {
    let volume = parse_volume_inspect(include_str!("fixtures/docker_volume_inspect.json")).unwrap();
    assert_eq!(volume.name, "postgres_data");
    assert_eq!(
        volume.mountpoint,
        "/var/lib/docker/volumes/postgres_data/_data"
    );
    assert_eq!(
        volume.labels[0],
        ("com.example.service".to_string(), "postgres".to_string())
    );
}

#[test]
fn parses_restic_snapshots() {
    let repo = fixture_repo();
    let snapshots = parse_snapshots(include_str!("fixtures/restic_snapshots.json"), &repo).unwrap();
    assert_eq!(snapshots.len(), 2);
    assert_eq!(snapshots[0].id, "abc123snapshot");
    assert_eq!(snapshots[0].repository_id, "repo-1");
    assert_eq!(snapshots[0].tags, vec!["docker"]);
}

fn fixture_repo() -> BackupRepository {
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
