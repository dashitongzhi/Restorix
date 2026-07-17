use crate::docker::client::{DockerClient, DockerStatus, VolumeScan};
use crate::error::Result;
use crate::models::{BackupRepository, BackupSnapshot, DockerContainer};
use crate::restic::client::{ResticClient, ResticStatus};
use crate::storage::config::{AppConfig, ConfigStore};
use chrono::{DateTime, Utc};

pub(super) trait ConfigSource {
    fn load_config(&self) -> Result<AppConfig>;
}

impl ConfigSource for ConfigStore {
    fn load_config(&self) -> Result<AppConfig> {
        self.load()
    }
}

pub(super) trait DockerSource {
    fn status(&self) -> DockerStatus;
    fn containers(&self) -> Result<Vec<DockerContainer>>;
    fn volumes(&self) -> Result<VolumeScan>;
}

impl DockerSource for DockerClient {
    fn status(&self) -> DockerStatus {
        self.check()
    }

    fn containers(&self) -> Result<Vec<DockerContainer>> {
        self.scan_containers()
    }

    fn volumes(&self) -> Result<VolumeScan> {
        self.scan_volumes_with_errors()
    }
}

pub(super) trait BackupSource {
    fn status(&self) -> ResticStatus;
    fn snapshots(&self, repository: &BackupRepository) -> Result<Vec<BackupSnapshot>>;
}

impl BackupSource for ResticClient {
    fn status(&self) -> ResticStatus {
        self.check()
    }

    fn snapshots(&self, repository: &BackupRepository) -> Result<Vec<BackupSnapshot>> {
        self.snapshots(repository)
    }
}

pub(super) trait Clock {
    fn now(&self) -> DateTime<Utc>;
}

pub(super) struct SystemClock;

impl Clock for SystemClock {
    fn now(&self) -> DateTime<Utc> {
        Utc::now()
    }
}
