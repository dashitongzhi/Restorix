use thiserror::Error;

pub type Result<T> = std::result::Result<T, RestorixError>;

#[derive(Debug, Error)]
pub enum RestorixError {
    #[error("Docker is not installed. Restorix could not find Docker on this Mac.")]
    DockerNotInstalled,

    #[error("Docker is installed but not running. Please open Docker Desktop and try again.")]
    DockerNotRunning,

    #[error("Restic is not installed. Install restic with Homebrew: brew install restic")]
    ResticNotInstalled,

    #[error("Restic password is missing. Set {0} in your environment or update the repository settings.")]
    ResticPasswordMissing(String),

    #[error("Command failed: {program} {args}\n{stderr}")]
    CommandFailed {
        program: String,
        args: String,
        stderr: String,
    },

    #[error("Command timed out after {seconds}s: {program} {args}")]
    CommandTimedOut {
        program: String,
        args: String,
        seconds: u64,
    },

    #[error("JSON parse failed while reading {context}: {source}")]
    JsonParse {
        context: String,
        #[source]
        source: serde_json::Error,
    },

    #[error("Configuration error: {0}")]
    Config(String),

    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Unsupported backup tool: {0}")]
    UnsupportedBackupTool(String),
}
