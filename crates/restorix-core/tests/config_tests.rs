use restorix_core::models::BackupTool;
use restorix_core::storage::config::ConfigStore;

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
