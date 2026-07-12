use restorix_core::models::BackupTool;
use restorix_core::storage::config::ConfigStore;
use std::sync::{Arc, Barrier};

#[test]
fn stores_repository_without_password_value() {
    let temp_dir = tempfile::tempdir().unwrap();
    let store = ConfigStore::new(temp_dir.path().join("config.json"));

    let repo = store
        .add_repository(
            "Local Restic".to_string(),
            BackupTool::Restic,
            "/tmp/restic".to_string(),
            Some("RESTIC_PASSWORD".to_string()),
            Some("homelab".to_string()),
            true,
        )
        .unwrap();

    let config = store.load().unwrap();
    assert_eq!(config.repositories.len(), 1);
    assert_eq!(config.repositories[0].id, repo.id);
    assert_eq!(
        config.repositories[0].password_env_key.as_deref(),
        Some("RESTIC_PASSWORD")
    );

    let raw = std::fs::read_to_string(store.path()).unwrap();
    assert!(!raw.contains("super-secret-password"));
}

#[test]
fn updates_repository_enabled_state() {
    let temp_dir = tempfile::tempdir().unwrap();
    let store = ConfigStore::new(temp_dir.path().join("config.json"));

    let repo = store
        .add_repository(
            "Local Restic".to_string(),
            BackupTool::Restic,
            "/tmp/restic".to_string(),
            None,
            Some("homelab".to_string()),
            true,
        )
        .unwrap();

    let updated = store.set_repository_enabled(&repo.id, false).unwrap();
    assert!(!updated.enabled);

    let config = store.load().unwrap();
    assert!(!config.repositories[0].enabled);
    assert!(!config.repositories[0].updated_at.is_empty());
}

#[test]
fn empty_config_file_loads_defaults() {
    let temp_dir = tempfile::tempdir().unwrap();
    let path = temp_dir.path().join("config.json");
    std::fs::write(&path, "").unwrap();
    let store = ConfigStore::new(path);

    let config = store.load().unwrap();

    assert_eq!(config.stale_hours, 72);
    assert!(config.repositories.is_empty());
}

#[test]
fn updates_launch_at_login_setting() {
    let temp_dir = tempfile::tempdir().unwrap();
    let store = ConfigStore::new(temp_dir.path().join("config.json"));

    let config = store.set_value("launch_at_login", "true").unwrap();
    assert!(config.launch_at_login);

    let loaded = store.load().unwrap();
    assert!(loaded.launch_at_login);

    let config = store.set_value("launch_at_login", "false").unwrap();
    assert!(!config.launch_at_login);

    let loaded = store.load().unwrap();
    assert!(!loaded.launch_at_login);
}

#[test]
fn broken_config_file_is_backed_up_and_defaults_are_loaded() {
    let temp_dir = tempfile::tempdir().unwrap();
    let path = temp_dir.path().join("config.json");
    std::fs::write(&path, "{not-json").unwrap();
    let store = ConfigStore::new(path);

    let config = store.load().unwrap();

    assert_eq!(config.stale_hours, 72);
    assert!(config.repositories.is_empty());
    let repaired = std::fs::read_to_string(store.path()).unwrap();
    assert!(repaired.contains("\"stale_hours\": 72"));
    let backups = std::fs::read_dir(temp_dir.path())
        .unwrap()
        .filter_map(|entry| entry.ok())
        .filter(|entry| {
            entry
                .file_name()
                .to_string_lossy()
                .starts_with("config.json.broken-")
        })
        .collect::<Vec<_>>();
    assert_eq!(backups.len(), 1);
}

#[test]
fn old_config_missing_new_fields_preserves_existing_repositories() {
    let temp_dir = tempfile::tempdir().unwrap();
    let path = temp_dir.path().join("config.json");
    std::fs::write(
        &path,
        r#"{
          "stale_hours": 48,
          "loose_matching": false,
          "show_dock_icon": true,
          "notifications_enabled": false,
          "cli_path": "",
          "repositories": [{
            "id": "repo-1",
            "name": "Existing Restic",
            "tool": "Restic",
            "location": "/tmp/restic",
            "password_env_key": "RESTIC_PASSWORD",
            "enabled": true,
            "created_at": "2026-01-01T00:00:00Z",
            "updated_at": "2026-01-01T00:00:00Z"
          }]
        }"#,
    )
    .unwrap();

    let config = ConfigStore::new(path).load().unwrap();

    assert_eq!(config.stale_hours, 48);
    assert!(!config.launch_at_login);
    assert_eq!(config.repositories.len(), 1);
    assert_eq!(config.repositories[0].id, "repo-1");
    assert!(config.repositories[0].expected_hostname.is_none());
}

#[test]
fn concurrent_config_updates_preserve_both_changes() {
    let temp_dir = tempfile::tempdir().unwrap();
    let store = Arc::new(ConfigStore::new(temp_dir.path().join("config.json")));
    let barrier = Arc::new(Barrier::new(3));

    let stale_store = Arc::clone(&store);
    let stale_barrier = Arc::clone(&barrier);
    let stale_update = std::thread::spawn(move || {
        stale_barrier.wait();
        stale_store.set_value("stale_hours", "48")
    });

    let notification_store = Arc::clone(&store);
    let notification_barrier = Arc::clone(&barrier);
    let notification_update = std::thread::spawn(move || {
        notification_barrier.wait();
        notification_store.set_value("notifications_enabled", "true")
    });

    barrier.wait();
    stale_update.join().unwrap().unwrap();
    notification_update.join().unwrap().unwrap();

    let config = store.load().unwrap();
    assert_eq!(config.stale_hours, 48);
    assert!(config.notifications_enabled);
}

#[cfg(unix)]
#[test]
fn config_file_is_written_with_owner_only_permissions() {
    use std::os::unix::fs::PermissionsExt;

    let temp_dir = tempfile::tempdir().unwrap();
    let store = ConfigStore::new(temp_dir.path().join("config.json"));
    store.set_value("stale_hours", "48").unwrap();

    let mode = std::fs::metadata(store.path())
        .unwrap()
        .permissions()
        .mode();
    assert_eq!(mode & 0o077, 0);
}
