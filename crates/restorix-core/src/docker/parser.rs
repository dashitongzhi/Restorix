use crate::error::{RestorixError, Result};
use crate::models::{DockerVolume, DockerVolumeMount};
use serde::Deserialize;
use std::collections::BTreeMap;

#[derive(Debug, Clone)]
pub struct DockerContainerRow {
    pub id: String,
    pub name: String,
    pub image: String,
    pub status: String,
}

#[derive(Debug, Clone)]
pub struct DockerVolumeRow {
    pub name: String,
}

#[derive(Debug, Deserialize)]
struct DockerPsJsonRow {
    #[serde(rename = "ID")]
    id: String,
    #[serde(rename = "Names")]
    names: String,
    #[serde(rename = "Image")]
    image: String,
    #[serde(rename = "Status")]
    status: String,
}

#[derive(Debug, Deserialize)]
struct DockerVolumeLsJsonRow {
    #[serde(rename = "Name")]
    name: String,
}

#[derive(Debug, Deserialize)]
struct DockerInspectContainer {
    #[serde(rename = "Mounts", default)]
    mounts: Vec<DockerInspectMount>,
}

#[derive(Debug, Deserialize)]
struct DockerInspectMount {
    #[serde(rename = "Name")]
    name: Option<String>,
    #[serde(rename = "Source", default)]
    source: String,
    #[serde(rename = "Destination", default)]
    destination: String,
    #[serde(rename = "Mode")]
    mode: Option<String>,
    #[serde(rename = "Type")]
    mount_type: Option<String>,
}

#[derive(Debug, Deserialize)]
struct DockerInspectVolume {
    #[serde(rename = "Name")]
    name: String,
    #[serde(rename = "Driver")]
    driver: String,
    #[serde(rename = "Mountpoint")]
    mountpoint: String,
    #[serde(rename = "Labels", default)]
    labels: Option<BTreeMap<String, String>>,
}

pub fn parse_container_rows(input: &str) -> Result<Vec<DockerContainerRow>> {
    input
        .lines()
        .filter(|line| !line.trim().is_empty())
        .map(|line| {
            let row: DockerPsJsonRow =
                serde_json::from_str(line).map_err(|source| RestorixError::JsonParse {
                    context: "docker ps row".to_string(),
                    source,
                })?;
            Ok(DockerContainerRow {
                id: row.id,
                name: row.names,
                image: row.image,
                status: row.status,
            })
        })
        .collect()
}

pub fn parse_volume_rows(input: &str) -> Result<Vec<DockerVolumeRow>> {
    input
        .lines()
        .filter(|line| !line.trim().is_empty())
        .map(|line| {
            let row: DockerVolumeLsJsonRow =
                serde_json::from_str(line).map_err(|source| RestorixError::JsonParse {
                    context: "docker volume ls row".to_string(),
                    source,
                })?;
            Ok(DockerVolumeRow { name: row.name })
        })
        .collect()
}

pub fn parse_container_inspect(input: &str) -> Result<Vec<DockerVolumeMount>> {
    let containers: Vec<DockerInspectContainer> =
        serde_json::from_str(input).map_err(|source| RestorixError::JsonParse {
            context: "docker inspect container".to_string(),
            source,
        })?;

    Ok(containers
        .into_iter()
        .flat_map(|container| container.mounts)
        .filter(|mount| mount.mount_type.as_deref() == Some("volume") || mount.name.is_some())
        .map(|mount| DockerVolumeMount {
            volume_name: mount.name,
            source: mount.source,
            destination: mount.destination,
            mode: mount.mode,
        })
        .collect())
}

pub fn parse_volume_inspect(input: &str) -> Result<DockerVolume> {
    let mut volumes: Vec<DockerInspectVolume> =
        serde_json::from_str(input).map_err(|source| RestorixError::JsonParse {
            context: "docker volume inspect".to_string(),
            source,
        })?;
    let volume = volumes.pop().ok_or_else(|| {
        RestorixError::Config("docker volume inspect returned no volumes.".to_string())
    })?;
    let labels = volume
        .labels
        .unwrap_or_default()
        .into_iter()
        .collect::<Vec<(String, String)>>();

    Ok(DockerVolume {
        name: volume.name,
        driver: volume.driver,
        mountpoint: volume.mountpoint,
        labels,
    })
}
