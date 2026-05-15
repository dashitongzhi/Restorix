use crate::docker::client::DockerClient;
use crate::error::{RestorixError, Result};
use crate::models::{
    BackupRepository, BackupSnapshot, BackupTool, DockerContainer, DockerVolume, ScanResult,
};
use crate::report::markdown::{render_markdown_report_with_language, ReportLanguage};
use crate::restic::client::ResticClient;
use crate::scanner::engine::scan;
use crate::storage::config::{AppConfig, ConfigStore};

pub fn scan_json(config_store: &ConfigStore) -> ScanResult {
    scan(config_store)
}

pub fn markdown_report(config_store: &ConfigStore) -> String {
    markdown_report_with_language(config_store, "en")
}

pub fn markdown_report_with_language(config_store: &ConfigStore, language: &str) -> String {
    let result = scan(config_store);
    render_markdown_report_with_language(&result, ReportLanguage::from_code(language))
}

pub fn docker_check_json() -> serde_json::Value {
    let status = DockerClient::new().check();
    serde_json::json!({
        "installed": status.installed,
        "running": status.running,
        "version": status.version,
        "message": status.message,
    })
}

pub fn docker_containers_json() -> Result<Vec<DockerContainer>> {
    DockerClient::new().scan_containers()
}

pub fn docker_volumes_json() -> Result<Vec<DockerVolume>> {
    DockerClient::new().scan_volumes()
}

pub fn add_repository(
    config_store: &ConfigStore,
    tool: &str,
    name: String,
    location: String,
    password_env_key: Option<String>,
    enabled: bool,
) -> Result<BackupRepository> {
    let tool = parse_tool(tool)?;
    config_store.add_repository(name, tool, location, password_env_key, enabled)
}

pub fn list_repositories(config_store: &ConfigStore) -> Result<Vec<BackupRepository>> {
    Ok(config_store.load()?.repositories)
}

pub fn remove_repository(config_store: &ConfigStore, repo_id: &str) -> Result<bool> {
    config_store.remove_repository(repo_id)
}

pub fn test_repository(config_store: &ConfigStore, repo_id: &str) -> Result<Vec<BackupSnapshot>> {
    let config = config_store.load()?;
    let repo = config
        .repositories
        .iter()
        .find(|repo| repo.id == repo_id)
        .ok_or_else(|| RestorixError::Config(format!("Repository not found: {repo_id}")))?;
    ResticClient::new().snapshots(repo)
}

pub fn get_config(config_store: &ConfigStore) -> Result<AppConfig> {
    config_store.load()
}

pub fn set_config(config_store: &ConfigStore, key: &str, value: &str) -> Result<AppConfig> {
    config_store.set_value(key, value)
}

fn parse_tool(tool: &str) -> Result<BackupTool> {
    match tool.to_ascii_lowercase().as_str() {
        "restic" => Ok(BackupTool::Restic),
        other => Err(RestorixError::UnsupportedBackupTool(other.to_string())),
    }
}
