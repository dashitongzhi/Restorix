use crate::models::{BackupSnapshot, DockerVolume, MatchConfidence};
use chrono::{DateTime, Utc};
use std::path::{Component, Path};

#[derive(Debug, Clone)]
pub struct SnapshotMatch {
    pub snapshot: BackupSnapshot,
    pub confidence: MatchConfidence,
    pub matched_path: String,
}

pub fn best_snapshot_match(
    volume: &DockerVolume,
    snapshots: &[BackupSnapshot],
) -> Option<SnapshotMatch> {
    snapshots
        .iter()
        .flat_map(|snapshot| {
            snapshot.paths.iter().filter_map(|path| {
                let confidence = match_path(volume, path);
                if confidence == MatchConfidence::None {
                    None
                } else {
                    Some(SnapshotMatch {
                        snapshot: snapshot.clone(),
                        confidence,
                        matched_path: path.clone(),
                    })
                }
            })
        })
        .max_by(|a, b| {
            reliable_rank(&a.confidence)
                .cmp(&reliable_rank(&b.confidence))
                .then_with(|| snapshot_time_rank(&a.snapshot).cmp(&snapshot_time_rank(&b.snapshot)))
                .then_with(|| confidence_rank(&a.confidence).cmp(&confidence_rank(&b.confidence)))
        })
}

pub fn match_path(volume: &DockerVolume, snapshot_path: &str) -> MatchConfidence {
    let mountpoint = normalize_path(&volume.mountpoint);
    let snapshot_path = normalize_path(snapshot_path);

    if mountpoint.is_empty() || snapshot_path.is_empty() {
        return MatchConfidence::None;
    }

    if mountpoint == snapshot_path {
        return MatchConfidence::Exact;
    }

    let mount_path = Path::new(&mountpoint);
    let snapshot = Path::new(&snapshot_path);

    if mount_path.starts_with(snapshot) {
        return MatchConfidence::ParentPath;
    }

    if snapshot.starts_with(mount_path) {
        return MatchConfidence::ChildPath;
    }

    if path_contains_component(snapshot, &volume.name) {
        return MatchConfidence::VolumeName;
    }

    MatchConfidence::None
}

pub fn is_reliable_match(confidence: &MatchConfidence, loose_matching: bool) -> bool {
    matches!(
        confidence,
        MatchConfidence::Exact | MatchConfidence::ParentPath | MatchConfidence::ChildPath
    ) || (loose_matching && matches!(confidence, MatchConfidence::VolumeName))
}

fn normalize_path(path: &str) -> String {
    let trimmed = path.trim();
    if trimmed == "/" {
        return trimmed.to_string();
    }
    trimmed.trim_end_matches('/').to_string()
}

fn path_contains_component(path: &Path, name: &str) -> bool {
    path.components().any(|component| match component {
        Component::Normal(value) => value.to_string_lossy() == name,
        _ => false,
    })
}

fn confidence_rank(confidence: &MatchConfidence) -> u8 {
    match confidence {
        MatchConfidence::Exact => 5,
        MatchConfidence::ParentPath => 4,
        MatchConfidence::ChildPath => 4,
        MatchConfidence::VolumeName => 2,
        MatchConfidence::Low => 1,
        MatchConfidence::None => 0,
    }
}

fn reliable_rank(confidence: &MatchConfidence) -> u8 {
    match confidence {
        MatchConfidence::Exact | MatchConfidence::ParentPath | MatchConfidence::ChildPath => 2,
        MatchConfidence::VolumeName | MatchConfidence::Low => 1,
        MatchConfidence::None => 0,
    }
}

fn snapshot_time_rank(snapshot: &BackupSnapshot) -> i64 {
    DateTime::parse_from_rfc3339(&snapshot.time)
        .map(|time| time.with_timezone(&Utc).timestamp())
        .unwrap_or_default()
}
