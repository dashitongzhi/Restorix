use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum DiagnosticCode {
    ConfigLoadFailed,
    DockerUnavailable,
    ResticUnavailable,
    ResticCheckFailed,
    DockerContainerScanFailed,
    DockerVolumeScanFailed,
    DockerVolumeInspectFailed,
    RepositoryScanFailed,
    ResticRequiredMissing,
    BackupVerificationUnconfigured,
    StatefulVolumes,
    VolumeMountpointMissing,
    NoEnabledRepositories,
    NoSnapshotMatch,
    MissingExpectedHostname,
    ChildPathOnly,
    VolumeNameMatchOnly,
    UnreliableSnapshotMatch,
    FutureSnapshot,
    StaleSnapshot,
    RecentSnapshot,
    SnapshotTimeUnparseable,
    RepositoryCoverageUnknown,
    LooseMatchingDisabled,
    Generic,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
pub struct DiagnosticContext {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub hours: Option<u64>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub volumes: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub repository: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub detail: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Diagnostic {
    pub code: DiagnosticCode,
    #[serde(default)]
    pub context: DiagnosticContext,
    pub message: String,
}

impl Diagnostic {
    pub fn simple(code: DiagnosticCode, message: impl Into<String>) -> Self {
        Self {
            code,
            context: DiagnosticContext::default(),
            message: message.into(),
        }
    }

    pub fn with_detail(
        code: DiagnosticCode,
        message: impl Into<String>,
        detail: impl Into<String>,
    ) -> Self {
        Self {
            code,
            context: DiagnosticContext {
                detail: Some(detail.into()),
                ..Default::default()
            },
            message: message.into(),
        }
    }

    pub fn with_repository(
        code: DiagnosticCode,
        message: impl Into<String>,
        repository: impl Into<String>,
        detail: impl Into<String>,
    ) -> Self {
        Self {
            code,
            context: DiagnosticContext {
                repository: Some(repository.into()),
                detail: Some(detail.into()),
                ..Default::default()
            },
            message: message.into(),
        }
    }

    pub fn with_hours(code: DiagnosticCode, message: impl Into<String>, hours: u64) -> Self {
        Self {
            code,
            context: DiagnosticContext {
                hours: Some(hours),
                ..Default::default()
            },
            message: message.into(),
        }
    }

    pub fn with_volumes(
        code: DiagnosticCode,
        message: impl Into<String>,
        volumes: Vec<String>,
    ) -> Self {
        Self {
            code,
            context: DiagnosticContext {
                volumes,
                ..Default::default()
            },
            message: message.into(),
        }
    }
}
