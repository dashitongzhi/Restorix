use restorix_core::models::BackupTool;
use restorix_core::storage::config::{ConfigStore, SettingsDraft};
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

    let mut draft = default_draft();
    draft.launch_at_login = true;
    let config = store.commit_settings(draft.clone()).unwrap();
    assert!(config.launch_at_login);

    let loaded = store.load().unwrap();
    assert!(loaded.launch_at_login);

    draft.launch_at_login = false;
    let config = store.commit_settings(draft).unwrap();
    assert!(!config.launch_at_login);

    let loaded = store.load().unwrap();
    assert!(!loaded.launch_at_login);
}

#[test]
fn commits_all_settings_in_one_atomic_update() {
    let temp_dir = tempfile::tempdir().unwrap();
    let store = ConfigStore::new(temp_dir.path().join("config.json"));
    store
        .add_repository(
            "Local Restic".to_string(),
            BackupTool::Restic,
            "/tmp/restic".to_string(),
            None,
            Some("homelab".to_string()),
            true,
        )
        .unwrap();

    let committed = store
        .commit_settings(SettingsDraft {
            stale_hours: 48,
            loose_matching: true,
            show_dock_icon: false,
            launch_at_login: true,
            notifications_enabled: true,
            cli_path: "/opt/restorix".to_string(),
        })
        .unwrap();

    assert_eq!(committed.stale_hours, 48);
    assert!(committed.loose_matching);
    assert!(!committed.show_dock_icon);
    assert!(committed.launch_at_login);
    assert!(committed.notifications_enabled);
    assert_eq!(committed.cli_path, "/opt/restorix");
    assert_eq!(committed.repositories.len(), 1);
}

#[test]
fn rejects_invalid_settings_without_partial_commit() {
    let temp_dir = tempfile::tempdir().unwrap();
    let store = ConfigStore::new(temp_dir.path().join("config.json"));
    let mut existing = default_draft();
    existing.notifications_enabled = true;
    store.commit_settings(existing).unwrap();

    let error = store
        .commit_settings(SettingsDraft {
            stale_hours: 0,
            loose_matching: true,
            show_dock_icon: false,
            launch_at_login: true,
            notifications_enabled: false,
            cli_path: "/invalid".to_string(),
        })
        .unwrap_err();

    assert!(error.to_string().contains("between 1 and 720"));
    let loaded = store.load().unwrap();
    assert_eq!(loaded.stale_hours, 72);
    assert!(loaded.notifications_enabled);
    assert!(loaded.show_dock_icon);
    assert!(!loaded.launch_at_login);
    assert!(loaded.cli_path.is_empty());
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
fn concurrent_repository_and_settings_updates_preserve_both_changes() {
    let temp_dir = tempfile::tempdir().unwrap();
    let store = Arc::new(ConfigStore::new(temp_dir.path().join("config.json")));
    let barrier = Arc::new(Barrier::new(3));

    let settings_store = Arc::clone(&store);
    let settings_barrier = Arc::clone(&barrier);
    let settings_update = std::thread::spawn(move || {
        settings_barrier.wait();
        let mut draft = default_draft();
        draft.stale_hours = 48;
        draft.notifications_enabled = true;
        settings_store.commit_settings(draft)
    });

    let repository_store = Arc::clone(&store);
    let repository_barrier = Arc::clone(&barrier);
    let repository_update = std::thread::spawn(move || {
        repository_barrier.wait();
        repository_store.add_repository(
            "Concurrent Restic".to_string(),
            BackupTool::Restic,
            "/tmp/restic".to_string(),
            None,
            Some("homelab".to_string()),
            true,
        )
    });

    barrier.wait();
    settings_update.join().unwrap().unwrap();
    repository_update.join().unwrap().unwrap();

    let config = store.load().unwrap();
    assert_eq!(config.stale_hours, 48);
    assert!(config.notifications_enabled);
    assert_eq!(config.repositories.len(), 1);
}

#[cfg(unix)]
#[test]
fn config_file_is_written_with_owner_only_permissions() {
    use std::os::unix::fs::PermissionsExt;

    let temp_dir = tempfile::tempdir().unwrap();
    let store = ConfigStore::new(temp_dir.path().join("config.json"));
    let mut draft = default_draft();
    draft.stale_hours = 48;
    store.commit_settings(draft).unwrap();

    let mode = std::fs::metadata(store.path())
        .unwrap()
        .permissions()
        .mode();
    assert_eq!(mode & 0o077, 0);
}

fn default_draft() -> SettingsDraft {
    SettingsDraft {
        stale_hours: 72,
        loose_matching: false,
        show_dock_icon: true,
        launch_at_login: false,
        notifications_enabled: false,
        cli_path: String::new(),
    }
}
