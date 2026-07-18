use crate::docker::client::{DockerStatus, VolumeScan};
use crate::error::{RestorixError, Result};
use crate::models::{BackupRepository, BackupSnapshot, BackupTool, DockerContainer, DockerVolume};
use crate::restic::client::ResticStatus;
use crate::scanner::sources::{BackupSource, Clock, ConfigSource, DockerSource};
use crate::storage::config::AppConfig;
use chrono::{DateTime, TimeZone, Utc};

pub(super) struct FixedConfig {
    config: Option<AppConfig>,
    error: Option<String>,
}

impl FixedConfig {
    pub(super) fn success(config: AppConfig) -> Self {
        Self {
            config: Some(config),
            error: None,
        }
    }

    pub(super) fn failure(message: &str) -> Self {
        Self {
            config: None,
            error: Some(message.to_string()),
        }
    }
}

impl ConfigSource for FixedConfig {
    fn load_config(&self) -> Result<AppConfig> {
        match (&self.config, &self.error) {
            (Some(config), _) => Ok(config.clone()),
            (_, Some(error)) => Err(RestorixError::Config(error.clone())),
            _ => unreachable!("fixed config requires a value or an error"),
        }
    }
}

pub(super) struct FakeDocker {
    status: DockerStatus,
    containers: Vec<DockerContainer>,
    volumes: Vec<DockerVolume>,
    pub(super) volume_errors: Vec<String>,
    container_failure: Option<String>,
    volume_failure: Option<String>,
}

impl FakeDocker {
    pub(super) fn running(volumes: Vec<DockerVolume>) -> Self {
        Self {
            status: DockerStatus {
                installed: true,
                running: true,
                version: Some("Docker fixture".to_string()),
                message: None,
            },
            containers: Vec::new(),
            volumes,
            volume_errors: Vec::new(),
            container_failure: None,
            volume_failure: None,
        }
    }

    pub(super) fn missing() -> Self {
        Self {
            status: DockerStatus {
                installed: false,
                running: false,
                version: None,
                message: Some(
                    "Docker is not installed. Restorix could not find Docker on this Mac."
                        .to_string(),
                ),
            },
            containers: Vec::new(),
            volumes: Vec::new(),
            volume_errors: Vec::new(),
            container_failure: None,
            volume_failure: None,
        }
    }
}

impl DockerSource for FakeDocker {
    fn status(&self) -> DockerStatus {
        self.status.clone()
    }

    fn containers(&self) -> Result<Vec<DockerContainer>> {
        if let Some(error) = &self.container_failure {
            return Err(RestorixError::Config(error.clone()));
        }
        Ok(self.containers.clone())
    }

    fn volumes(&self) -> Result<VolumeScan> {
        if let Some(error) = &self.volume_failure {
            return Err(RestorixError::Config(error.clone()));
        }
        Ok(VolumeScan {
            volumes: self.volumes.clone(),
            errors: self.volume_errors.clone(),
        })
    }
}

pub(super) struct FakeBackup {
    status: ResticStatus,
    snapshots: Vec<BackupSnapshot>,
    failure: Option<String>,
}

impl FakeBackup {
    pub(super) fn installed(snapshots: Vec<BackupSnapshot>) -> Self {
        Self {
            status: ResticStatus {
                installed: true,
                version: Some("restic fixture".to_string()),
                message: None,
            },
            snapshots,
            failure: None,
        }
    }

    pub(super) fn failing(message: &str) -> Self {
        Self {
            status: ResticStatus {
                installed: true,
                version: Some("restic fixture".to_string()),
                message: None,
            },
            snapshots: Vec::new(),
            failure: Some(message.to_string()),
        }
    }

    pub(super) fn missing() -> Self {
        Self {
            status: ResticStatus {
                installed: false,
                version: None,
                message: Some(
                    "Restic is not installed. Install restic with Homebrew: brew install restic"
                        .to_string(),
                ),
            },
            snapshots: Vec::new(),
            failure: None,
        }
    }

    pub(super) fn check_failed(message: &str) -> Self {
        Self {
            status: ResticStatus {
                installed: true,
                version: None,
                message: Some(message.to_string()),
            },
            snapshots: Vec::new(),
            failure: None,
        }
    }
}

impl BackupSource for FakeBackup {
    fn status(&self) -> ResticStatus {
        self.status.clone()
    }

    fn snapshots(&self, _repository: &BackupRepository) -> Result<Vec<BackupSnapshot>> {
        if let Some(error) = &self.failure {
            return Err(RestorixError::Config(error.clone()));
        }
        Ok(self.snapshots.clone())
    }
}

pub(super) struct FixedClock(DateTime<Utc>);

impl FixedClock {
    pub(super) fn at(year: i32, month: u32, day: u32, hour: u32) -> Self {
        Self(Utc.with_ymd_and_hms(year, month, day, hour, 0, 0).unwrap())
    }
}

impl Clock for FixedClock {
    fn now(&self) -> DateTime<Utc> {
        self.0
    }
}

pub(super) fn config_with_repository() -> AppConfig {
    AppConfig {
        repositories: vec![repository()],
        ..AppConfig::default()
    }
}

fn repository() -> BackupRepository {
    BackupRepository {
        id: "repo-1".to_string(),
        name: "Local Restic".to_string(),
        tool: BackupTool::Restic,
        location: "/tmp/restic".to_string(),
        password_env_key: None,
        expected_hostname: Some("homelab".to_string()),
        enabled: true,
        created_at: "2026-05-15T00:00:00Z".to_string(),
        updated_at: "2026-05-15T00:00:00Z".to_string(),
    }
}

pub(super) fn volume(name: &str) -> DockerVolume {
    DockerVolume {
        name: name.to_string(),
        driver: "local".to_string(),
        mountpoint: format!("/var/lib/docker/volumes/{name}/_data"),
        labels: Vec::new(),
    }
}

pub(super) fn snapshot(time: &str) -> BackupSnapshot {
    BackupSnapshot {
        id: "snapshot-1".to_string(),
        repository_id: "repo-1".to_string(),
        tool: BackupTool::Restic,
        time: time.to_string(),
        paths: vec!["/var/lib/docker/volumes/postgres_data/_data".to_string()],
        size_bytes: None,
        hostname: Some("homelab".to_string()),
        tags: Vec::new(),
    }
}
