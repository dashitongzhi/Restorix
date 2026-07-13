use crate::error::{RestorixError, Result};
use crate::models::{BackupRepository, BackupTool};
use chrono::Utc;
use fs2::FileExt;
use serde::{Deserialize, Serialize};
use std::fs::{self, File, OpenOptions};
use std::io::Write;
#[cfg(unix)]
use std::os::unix::fs::{OpenOptionsExt, PermissionsExt};
use std::path::{Path, PathBuf};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default)]
pub struct AppConfig {
    pub stale_hours: u64,
    pub loose_matching: bool,
    pub show_dock_icon: bool,
    pub launch_at_login: bool,
    pub notifications_enabled: bool,
    pub cli_path: String,
    pub repositories: Vec<BackupRepository>,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            stale_hours: 72,
            loose_matching: false,
            show_dock_icon: true,
            launch_at_login: false,
            notifications_enabled: false,
            cli_path: String::new(),
            repositories: Vec::new(),
        }
    }
}

#[derive(Debug, Clone)]
pub struct ConfigStore {
    path: PathBuf,
}

impl ConfigStore {
    pub fn default_path() -> Result<PathBuf> {
        if let Ok(path) = std::env::var("RESTORIX_CONFIG") {
            return Ok(PathBuf::from(path));
        }

        let base = dirs_next::data_dir().ok_or_else(|| {
            RestorixError::Config("Could not locate user data directory.".to_string())
        })?;
        Ok(base.join("Restorix").join("config.json"))
    }

    pub fn new(path: PathBuf) -> Self {
        Self { path }
    }

    pub fn from_default_path() -> Result<Self> {
        Ok(Self::new(Self::default_path()?))
    }

    pub fn path(&self) -> &Path {
        &self.path
    }

    pub fn load(&self) -> Result<AppConfig> {
        let _lock = self.acquire_lock()?;
        self.load_unlocked()
    }

    pub fn save(&self, config: &AppConfig) -> Result<()> {
        let _lock = self.acquire_lock()?;
        self.save_unlocked(config)
    }

    fn load_unlocked(&self) -> Result<AppConfig> {
        if !self.path.exists() {
            return Ok(AppConfig::default());
        }

        let data = fs::read_to_string(&self.path)?;
        if data.trim().is_empty() {
            return Ok(AppConfig::default());
        }

        match serde_json::from_str(&data) {
            Ok(config) => Ok(config),
            Err(_) => {
                self.backup_broken_config(&data)?;
                let config = AppConfig::default();
                self.save_unlocked(&config)?;
                Ok(config)
            }
        }
    }

    fn save_unlocked(&self, config: &AppConfig) -> Result<()> {
        let data =
            serde_json::to_string_pretty(config).map_err(|source| RestorixError::JsonParse {
                context: "config serialization".to_string(),
                source,
            })?;
        self.write_atomically(&self.path, data.as_bytes())
    }

    pub fn add_repository(
        &self,
        name: String,
        tool: BackupTool,
        location: String,
        password_env_key: Option<String>,
        expected_hostname: Option<String>,
        enabled: bool,
    ) -> Result<BackupRepository> {
        self.update(|config| {
            let now = Utc::now().to_rfc3339();
            let repo = BackupRepository {
                id: Uuid::new_v4().to_string(),
                name,
                tool,
                location,
                password_env_key: password_env_key.filter(|value| !value.trim().is_empty()),
                expected_hostname: expected_hostname.filter(|value| !value.trim().is_empty()),
                enabled,
                created_at: now.clone(),
                updated_at: now,
            };
            config.repositories.push(repo.clone());
            Ok(repo)
        })
    }

    pub fn remove_repository(&self, repo_id: &str) -> Result<bool> {
        self.update(|config| {
            let original_len = config.repositories.len();
            config.repositories.retain(|repo| repo.id != repo_id);
            Ok(config.repositories.len() != original_len)
        })
    }

    pub fn set_repository_enabled(&self, repo_id: &str, enabled: bool) -> Result<BackupRepository> {
        self.update(|config| {
            let now = Utc::now().to_rfc3339();
            let repo = config
                .repositories
                .iter_mut()
                .find(|repo| repo.id == repo_id)
                .ok_or_else(|| RestorixError::Config(format!("Repository not found: {repo_id}")))?;

            repo.enabled = enabled;
            repo.updated_at = now;
            Ok(repo.clone())
        })
    }

    pub fn set_value(&self, key: &str, value: &str) -> Result<AppConfig> {
        self.update(|config| {
            match key {
                "stale_hours" => {
                    config.stale_hours = value.parse::<u64>().map_err(|_| {
                        RestorixError::Config("stale_hours must be an integer.".to_string())
                    })?;
                }
                "loose_matching" => {
                    config.loose_matching = parse_bool(value)?;
                }
                "show_dock_icon" => {
                    config.show_dock_icon = parse_bool(value)?;
                }
                "launch_at_login" => {
                    config.launch_at_login = parse_bool(value)?;
                }
                "notifications_enabled" => {
                    config.notifications_enabled = parse_bool(value)?;
                }
                "cli_path" => {
                    config.cli_path = value.to_string();
                }
                other => {
                    return Err(RestorixError::Config(format!(
                        "Unknown config key: {other}"
                    )));
                }
            }
            Ok(config.clone())
        })
    }

    fn update<T>(&self, mutation: impl FnOnce(&mut AppConfig) -> Result<T>) -> Result<T> {
        let _lock = self.acquire_lock()?;
        let mut config = self.load_unlocked()?;
        let result = mutation(&mut config)?;
        self.save_unlocked(&config)?;
        Ok(result)
    }

    fn acquire_lock(&self) -> Result<File> {
        let parent = self.config_parent()?;
        fs::create_dir_all(parent)?;
        let lock_path = self.path.with_file_name(format!(
            ".{}.lock",
            self.path
                .file_name()
                .and_then(|name| name.to_str())
                .unwrap_or("config.json")
        ));
        let lock = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .open(lock_path)?;
        lock.lock_exclusive()?;
        Ok(lock)
    }

    fn write_atomically(&self, path: &Path, data: &[u8]) -> Result<()> {
        let parent = path.parent().ok_or_else(|| {
            RestorixError::Config("Configuration path has no parent directory.".to_string())
        })?;
        fs::create_dir_all(parent)?;
        let file_name = path
            .file_name()
            .and_then(|name| name.to_str())
            .unwrap_or("config");
        let temporary_path = parent.join(format!(".{file_name}.{}.tmp", Uuid::new_v4()));

        let write_result = (|| -> Result<()> {
            let mut options = OpenOptions::new();
            options.write(true).create_new(true);
            #[cfg(unix)]
            options.mode(0o600);
            let mut temporary_file = options.open(&temporary_path)?;
            temporary_file.write_all(data)?;
            temporary_file.sync_all()?;
            fs::rename(&temporary_path, path)?;
            #[cfg(unix)]
            fs::set_permissions(path, fs::Permissions::from_mode(0o600))?;
            File::open(parent)?.sync_all()?;
            Ok(())
        })();

        if write_result.is_err() {
            let _ = fs::remove_file(&temporary_path);
        }
        write_result
    }

    fn config_parent(&self) -> Result<&Path> {
        self.path.parent().ok_or_else(|| {
            RestorixError::Config("Configuration path has no parent directory.".to_string())
        })
    }

    fn backup_broken_config(&self, data: &str) -> Result<()> {
        let file_name = self
            .path
            .file_name()
            .and_then(|name| name.to_str())
            .unwrap_or("config.json");
        let timestamp = Utc::now().format("%Y%m%dT%H%M%SZ");
        let backup_name = format!("{file_name}.broken-{timestamp}");
        let backup_path = self.path.with_file_name(backup_name);
        self.write_atomically(&backup_path, data.as_bytes())
    }
}

fn parse_bool(value: &str) -> Result<bool> {
    match value {
        "true" | "1" | "yes" | "on" => Ok(true),
        "false" | "0" | "no" | "off" => Ok(false),
        _ => Err(RestorixError::Config(
            "Boolean value must be true or false.".to_string(),
        )),
    }
}
