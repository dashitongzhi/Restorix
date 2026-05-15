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

pub fn parse_snapshots(input: &str, repository: &BackupRepository) -> Result<Vec<BackupSnapshot>> {
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
