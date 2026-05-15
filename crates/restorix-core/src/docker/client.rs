use crate::docker::parser::{
    parse_container_inspect, parse_container_rows, parse_volume_inspect, parse_volume_rows,
};
use crate::error::{RestorixError, Result};
use crate::models::{DockerContainer, DockerVolume};
use std::process::Command;

#[derive(Debug, Clone)]
pub struct DockerStatus {
    pub installed: bool,
    pub running: bool,
    pub version: Option<String>,
    pub message: Option<String>,
}

#[derive(Debug, Default, Clone)]
pub struct DockerClient;

impl DockerClient {
    pub fn new() -> Self {
        Self
    }

    pub fn check(&self) -> DockerStatus {
        if which::which("docker").is_err() {
            return DockerStatus {
                installed: false,
                running: false,
                version: None,
                message: Some(
                    "Docker is not installed. Restorix could not find Docker on this Mac."
                        .to_string(),
                ),
            };
        }

        let version = Command::new("docker")
            .arg("--version")
            .output()
            .ok()
            .filter(|output| output.status.success())
            .map(|output| String::from_utf8_lossy(&output.stdout).trim().to_string());

        let info = Command::new("docker")
            .args(["info", "--format", "{{json .}}"])
            .output();

        match info {
            Ok(output) if output.status.success() => DockerStatus {
                installed: true,
                running: true,
                version,
                message: None,
            },
            Ok(output) => DockerStatus {
                installed: true,
                running: false,
                version,
                message: Some(docker_not_running_message(&output.stderr)),
            },
            Err(_) => DockerStatus {
                installed: true,
                running: false,
                version,
                message: Some("Docker is installed but not running. Please open Docker Desktop and try again.".to_string()),
            },
        }
    }

    pub fn scan_containers(&self) -> Result<Vec<DockerContainer>> {
        ensure_docker_running(self)?;
        let output = run_docker(&["ps", "-a", "--format", "{{json .}}"])?;
        let rows = parse_container_rows(&output)?;
        let mut containers = Vec::with_capacity(rows.len());

        for row in rows {
            let inspect_json = run_docker(&["inspect", &row.id])?;
            let mounts = parse_container_inspect(&inspect_json)?;
            containers.push(DockerContainer {
                id: row.id,
                name: row.name,
                image: row.image,
                status: row.status.clone(),
                running: row.status.starts_with("Up"),
                volumes: mounts,
            });
        }

        Ok(containers)
    }

    pub fn scan_volumes(&self) -> Result<Vec<DockerVolume>> {
        ensure_docker_running(self)?;
        let output = run_docker(&["volume", "ls", "--format", "{{json .}}"])?;
        let rows = parse_volume_rows(&output)?;
        let mut volumes = Vec::with_capacity(rows.len());

        for row in rows {
            let inspect_json = run_docker(&["volume", "inspect", &row.name])?;
            volumes.push(parse_volume_inspect(&inspect_json)?);
        }

        volumes.sort_by(|a, b| a.name.cmp(&b.name));
        Ok(volumes)
    }
}

fn ensure_docker_running(client: &DockerClient) -> Result<()> {
    let status = client.check();
    if !status.installed {
        return Err(RestorixError::DockerNotInstalled);
    }
    if !status.running {
        return Err(RestorixError::DockerNotRunning);
    }
    Ok(())
}

fn run_docker(args: &[&str]) -> Result<String> {
    let output = Command::new("docker").args(args).output()?;
    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        Err(RestorixError::CommandFailed {
            program: "docker".to_string(),
            args: args.join(" "),
            stderr: clean_stderr(&output.stderr, "Docker command failed."),
        })
    }
}

fn clean_stderr(stderr: &[u8], fallback: &str) -> String {
    let text = String::from_utf8_lossy(stderr).trim().to_string();
    if text.is_empty() {
        fallback.to_string()
    } else {
        text
    }
}

fn docker_not_running_message(stderr: &[u8]) -> String {
    let details = String::from_utf8_lossy(stderr).trim().to_string();
    let base = "Docker is installed but not running. Please open Docker Desktop and try again.";
    if details.is_empty() {
        base.to_string()
    } else {
        format!("{base} Details: {details}")
    }
}
