use crate::error::{RestorixError, Result};
use crate::models::{BackupRepository, BackupTool};
use chrono::Utc;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
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

    pub fn default() -> Result<Self> {
        Ok(Self::new(Self::default_path()?))
    }

    pub fn path(&self) -> &Path {
        &self.path
    }

    pub fn load(&self) -> Result<AppConfig> {
        if !self.path.exists() {
            return Ok(AppConfig::default());
        }

        let data = fs::read_to_string(&self.path)?;
        serde_json::from_str(&data).map_err(|source| RestorixError::JsonParse {
            context: self.path.display().to_string(),
            source,
        })
    }

    pub fn save(&self, config: &AppConfig) -> Result<()> {
        if let Some(parent) = self.path.parent() {
            fs::create_dir_all(parent)?;
        }
        let data =
            serde_json::to_string_pretty(config).map_err(|source| RestorixError::JsonParse {
                context: "config serialization".to_string(),
                source,
            })?;
        fs::write(&self.path, data)?;
        Ok(())
    }

    pub fn add_repository(
        &self,
        name: String,
        tool: BackupTool,
        location: String,
        password_env_key: Option<String>,
        enabled: bool,
    ) -> Result<BackupRepository> {
        let mut config = self.load()?;
        let now = Utc::now().to_rfc3339();
        let repo = BackupRepository {
            id: Uuid::new_v4().to_string(),
            name,
            tool,
            location,
            password_env_key: password_env_key.filter(|value| !value.trim().is_empty()),
            enabled,
            created_at: now.clone(),
            updated_at: now,
        };
        config.repositories.push(repo.clone());
        self.save(&config)?;
        Ok(repo)
    }

    pub fn remove_repository(&self, repo_id: &str) -> Result<bool> {
        let mut config = self.load()?;
        let original_len = config.repositories.len();
        config.repositories.retain(|repo| repo.id != repo_id);
        let removed = config.repositories.len() != original_len;
        self.save(&config)?;
        Ok(removed)
    }

    pub fn set_value(&self, key: &str, value: &str) -> Result<AppConfig> {
        let mut config = self.load()?;
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
        self.save(&config)?;
        Ok(config)
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
