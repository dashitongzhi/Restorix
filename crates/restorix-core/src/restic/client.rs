use crate::error::{RestorixError, Result};
use crate::models::{BackupRepository, BackupSnapshot};
use crate::process::run_with_timeout;
use crate::restic::parser::parse_snapshots;
use std::process::Command;
use std::time::Duration;

const RESTIC_CHECK_TIMEOUT: Duration = Duration::from_secs(5);
const RESTIC_SNAPSHOTS_TIMEOUT: Duration = Duration::from_secs(120);

#[derive(Debug, Clone)]
pub struct ResticStatus {
    pub installed: bool,
    pub version: Option<String>,
    pub message: Option<String>,
}

#[derive(Debug, Default, Clone)]
pub struct ResticClient;

impl ResticClient {
    pub fn new() -> Self {
        Self
    }

    pub fn check(&self) -> ResticStatus {
        if which::which("restic").is_err() {
            return ResticStatus {
                installed: false,
                version: None,
                message: Some(
                    "Restic is not installed. Install restic with Homebrew: brew install restic"
                        .to_string(),
                ),
            };
        }

        let mut command = Command::new("restic");
        command.arg("version");

        match run_with_timeout(command, "restic", "version", RESTIC_CHECK_TIMEOUT) {
            Ok(output) if output.status.success() => ResticStatus {
                installed: true,
                version: Some(String::from_utf8_lossy(&output.stdout).trim().to_string()),
                message: None,
            },
            Ok(output) => ResticStatus {
                installed: true,
                version: None,
                message: Some(format!(
                    "Restic version check failed: {}",
                    clean_stderr(
                        &output.stderr,
                        "restic version returned a nonzero exit code."
                    )
                )),
            },
            Err(error) => ResticStatus {
                installed: true,
                version: None,
                message: Some(error.to_string()),
            },
        }
    }

    pub fn snapshots(&self, repository: &BackupRepository) -> Result<Vec<BackupSnapshot>> {
        if !self.check().installed {
            return Err(RestorixError::ResticNotInstalled);
        }

        let mut command = Command::new("restic");
        command
            .args(["snapshots", "--json"])
            .env("RESTIC_REPOSITORY", &repository.location);

        if let Some(key) = &repository.password_env_key {
            let value = std::env::var(key)
                .map_err(|_| RestorixError::ResticPasswordMissing(key.clone()))?;
            command.env("RESTIC_PASSWORD", value);
        }

        let output = run_with_timeout(
            command,
            "restic",
            "snapshots --json",
            RESTIC_SNAPSHOTS_TIMEOUT,
        )?;
        if !output.status.success() {
            return Err(RestorixError::CommandFailed {
                program: "restic".to_string(),
                args: "snapshots --json".to_string(),
                stderr: clean_stderr(&output.stderr, "Repository cannot be opened."),
            });
        }

        parse_snapshots(&String::from_utf8_lossy(&output.stdout), repository)
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
