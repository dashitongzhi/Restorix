use crate::error::{RestorixError, Result};
use crate::models::{BackupRepository, BackupSnapshot, BackupTool};
use serde::Deserialize;

#[derive(Debug, Deserialize)]
struct ResticSnapshotRow {
    id: Option<String>,
    short_id: Option<String>,
    time: String,
    #[serde(default)]
    paths: Vec<String>,
    hostname: Option<String>,
    #[serde(default)]
    tags: Vec<String>,
}

pub(crate) fn parse_snapshots(
    input: &str,
    repository: &BackupRepository,
) -> Result<Vec<BackupSnapshot>> {
    let rows: Vec<ResticSnapshotRow> =
        serde_json::from_str(input).map_err(|source| RestorixError::JsonParse {
            context: "restic snapshots --json".to_string(),
            source,
        })?;

    Ok(rows
        .into_iter()
        .map(|row| BackupSnapshot {
            id: row
                .id
                .or(row.short_id)
                .unwrap_or_else(|| "unknown".to_string()),
            repository_id: repository.id.clone(),
            tool: BackupTool::Restic,
            time: row.time,
            paths: row.paths,
            size_bytes: None,
            hostname: row.hostname,
            tags: row.tags,
        })
        .collect())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_restic_snapshots() {
        let repo = fixture_repo();
        let snapshots = parse_snapshots(
            include_str!("../../tests/fixtures/restic_snapshots.json"),
            &repo,
        )
        .unwrap();
        assert_eq!(snapshots.len(), 2);
        assert_eq!(snapshots[0].id, "abc123snapshot");
        assert_eq!(snapshots[0].repository_id, "repo-1");
        assert_eq!(snapshots[0].tags, vec!["docker"]);
    }

    fn fixture_repo() -> BackupRepository {
        BackupRepository {
            id: "repo-1".to_string(),
            name: "Local Restic".to_string(),
            tool: BackupTool::Restic,
            location: "/tmp/restic".to_string(),
            password_env_key: Some("RESTIC_PASSWORD".to_string()),
            expected_hostname: Some("homelab".to_string()),
            enabled: true,
            created_at: "2026-05-15T00:00:00Z".to_string(),
            updated_at: "2026-05-15T00:00:00Z".to_string(),
        }
    }
}
