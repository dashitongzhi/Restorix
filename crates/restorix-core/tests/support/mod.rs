#![allow(dead_code)]

use restorix_core::models::{BackupRepository, BackupSnapshot, BackupTool, DockerVolume};

pub fn volume(name: &str, mountpoint: &str) -> DockerVolume {
    DockerVolume {
        name: name.to_string(),
        driver: "local".to_string(),
        mountpoint: mountpoint.to_string(),
        labels: Vec::new(),
    }
}

pub fn repo() -> BackupRepository {
    BackupRepository {
        id: "repo-1".to_string(),
        name: "Local Restic".to_string(),
        tool: BackupTool::Restic,
        location: "/tmp/restic".to_string(),
        password_env_key: Some("RESTIC_PASSWORD".to_string()),
        expected_hostname: Some("homelab".to_string()),
        enabled: true,
        created_at: "2026-05-15T00:00:00Z".to_string(),
        updated_at: "2026-05-15T00:00:00Z".to_string(),
    }
}

pub fn snapshot(id: &str, time: &str, path: &str) -> BackupSnapshot {
    BackupSnapshot {
        id: id.to_string(),
        repository_id: "repo-1".to_string(),
        tool: BackupTool::Restic,
        time: time.to_string(),
        paths: vec![path.to_string()],
        size_bytes: None,
        hostname: Some("homelab".to_string()),
        tags: vec!["docker".to_string()],
    }
}
