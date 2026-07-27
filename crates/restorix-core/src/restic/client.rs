use crate::error::{RestorixError, Result};
use crate::models::{BackupRepository, BackupSnapshot};
use crate::process::run_with_timeout;
use crate::restic::parser::parse_snapshots;
use std::process::{Command, Stdio};
use std::time::Duration;

const RESTIC_CHECK_TIMEOUT: Duration = Duration::from_secs(5);
const RESTIC_SNAPSHOTS_TIMEOUT: Duration = Duration::from_secs(120);
const RESTIC_PASSWORD_ENV_KEYS: [&str; 3] = [
    "RESTIC_PASSWORD",
    "RESTIC_PASSWORD_FILE",
    "RESTIC_PASSWORD_COMMAND",
];

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
        let credential_env_keys = repository
            .password_env_key
            .iter()
            .cloned()
            .collect::<Vec<_>>();
        self.snapshots_with_credential_keys(repository, &credential_env_keys)
    }

    pub fn snapshots_with_credential_keys(
        &self,
        repository: &BackupRepository,
        credential_env_keys: &[String],
    ) -> Result<Vec<BackupSnapshot>> {
        if !self.check().installed {
            return Err(RestorixError::ResticNotInstalled);
        }

        let password = repository
            .password_env_key
            .as_ref()
            .map(|key| {
                std::env::var(key).map_err(|_| RestorixError::ResticPasswordMissing(key.clone()))
            })
            .transpose()?;
        let command = snapshots_command(repository, password.as_deref(), credential_env_keys);

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

fn snapshots_command(
    repository: &BackupRepository,
    password: Option<&str>,
    credential_env_keys: &[String],
) -> Command {
    let mut command = Command::new("restic");
    command.args(["snapshots", "--json"]).stdin(Stdio::null());

    for key in RESTIC_PASSWORD_ENV_KEYS {
        command.env_remove(key);
    }
    for key in credential_env_keys {
        command.env_remove(key);
    }

    command.env("RESTIC_REPOSITORY", &repository.location);
    if let Some(password) = password {
        command.env("RESTIC_PASSWORD", password);
    }

    command
}

fn clean_stderr(stderr: &[u8], fallback: &str) -> String {
    let text = String::from_utf8_lossy(stderr).trim().to_string();
    if text.is_empty() {
        fallback.to_string()
    } else {
        text
    }
}

#[cfg(test)]
mod tests {
    use super::snapshots_command;
    use crate::models::{BackupRepository, BackupTool};
    use std::ffi::OsStr;

    #[test]
    fn snapshots_command_clears_inherited_password_sources_and_sets_current_password() {
        let credential_env_keys =
            vec!["REPO_A_PASSWORD".to_string(), "REPO_B_PASSWORD".to_string()];
        let command = snapshots_command(
            &repository(),
            Some("current-password"),
            &credential_env_keys,
        );
        let environment = command.get_envs().collect::<Vec<_>>();

        assert_eq!(
            environment_value(&environment, "RESTIC_PASSWORD"),
            Some(Some(OsStr::new("current-password")))
        );
        assert_eq!(
            environment_value(&environment, "RESTIC_PASSWORD_FILE"),
            Some(None)
        );
        assert_eq!(
            environment_value(&environment, "RESTIC_PASSWORD_COMMAND"),
            Some(None)
        );
        assert_eq!(
            environment_value(&environment, "RESTIC_REPOSITORY"),
            Some(Some(OsStr::new("/tmp/restic")))
        );
        assert_eq!(
            environment_value(&environment, "REPO_A_PASSWORD"),
            Some(None)
        );
        assert_eq!(
            environment_value(&environment, "REPO_B_PASSWORD"),
            Some(None)
        );
    }

    #[test]
    fn snapshots_command_without_password_removes_every_password_source() {
        let command = snapshots_command(
            &repository(),
            None,
            &["OTHER_REPOSITORY_PASSWORD".to_string()],
        );
        let environment = command.get_envs().collect::<Vec<_>>();

        for key in [
            "RESTIC_PASSWORD",
            "RESTIC_PASSWORD_FILE",
            "RESTIC_PASSWORD_COMMAND",
        ] {
            assert_eq!(environment_value(&environment, key), Some(None));
        }
        assert_eq!(
            environment_value(&environment, "OTHER_REPOSITORY_PASSWORD"),
            Some(None)
        );
    }

    fn environment_value<'a>(
        environment: &'a [(&'a OsStr, Option<&'a OsStr>)],
        key: &str,
    ) -> Option<Option<&'a OsStr>> {
        environment
            .iter()
            .find_map(|(name, value)| (*name == OsStr::new(key)).then_some(*value))
    }

    fn repository() -> BackupRepository {
        BackupRepository {
            id: "repo-1".to_string(),
            name: "Local Restic".to_string(),
            tool: BackupTool::Restic,
            location: "/tmp/restic".to_string(),
            password_env_key: Some("RESTIC_BACKUP_PASSWORD".to_string()),
            expected_hostname: Some("host".to_string()),
            enabled: true,
            created_at: "2026-05-15T00:00:00Z".to_string(),
            updated_at: "2026-05-15T00:00:00Z".to_string(),
        }
    }
}
