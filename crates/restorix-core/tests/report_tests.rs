use restorix_core::models::{
    BackupRepository, BackupTool, DockerVolume, HealthStatus, MatchConfidence, Platform,
    ScanResult, ScanSummary, VolumeHealth,
};
use restorix_core::report::markdown::{
    render_markdown_report, render_markdown_report_with_language, ReportLanguage,
};

#[test]
fn renders_markdown_report_sections() {
    let report = render_markdown_report(&scan_result());
    assert!(report.contains("# Restorix Report"));
    assert!(report.contains("## Summary"));
    assert!(report.contains("- Docker running: Yes"));
    assert!(report.contains("## Unprotected Volumes"));
    assert!(report.contains("## Unknown Volumes"));
    assert!(report.contains("postgres_data"));
    assert!(report.contains("redis_data"));
    assert!(report.contains("restic restore snap-1"));
}

#[test]
fn renders_simplified_chinese_markdown_report() {
    let report =
        render_markdown_report_with_language(&scan_result(), ReportLanguage::SimplifiedChinese);

    assert!(report.contains("# Restorix 报告"));
    assert!(report.contains("## 摘要"));
    assert!(report.contains("- Docker 运行中: 是"));
    assert!(report.contains("## 未保护 Volumes"));
    assert!(report.contains("## 未知 Volumes"));
    assert!(report.contains("没有可靠的 snapshot 路径匹配这个 Docker volume 挂载点"));
    assert!(report.contains("宽松匹配已关闭"));
}

fn scan_result() -> ScanResult {
    let volume = DockerVolume {
        name: "postgres_data".to_string(),
        driver: "local".to_string(),
        mountpoint: "/var/lib/docker/volumes/postgres_data/_data".to_string(),
        labels: Vec::new(),
    };
    let unknown_volume = DockerVolume {
        name: "redis_data".to_string(),
        driver: "local".to_string(),
        mountpoint: "/var/lib/docker/volumes/redis_data/_data".to_string(),
        labels: Vec::new(),
    };

    ScanResult {
        summary: ScanSummary {
            scanned_at: "2026-05-15T10:00:00Z".to_string(),
            platform: Platform::MacOS,
            docker_available: true,
            docker_running: true,
            restic_available: true,
            total_containers: 1,
            total_volumes: 2,
            protected_count: 0,
            unprotected_count: 1,
            stale_count: 0,
            unknown_count: 1,
            error_count: 0,
        },
        containers: Vec::new(),
        volumes: vec![volume.clone(), unknown_volume.clone()],
        repositories: vec![BackupRepository {
            id: "repo-1".to_string(),
            name: "Local Restic".to_string(),
            tool: BackupTool::Restic,
            location: "/tmp/restic".to_string(),
            password_env_key: None,
            enabled: true,
            created_at: "2026-05-15T00:00:00Z".to_string(),
            updated_at: "2026-05-15T00:00:00Z".to_string(),
        }],
        snapshots: Vec::new(),
        volume_health: vec![
            VolumeHealth {
                volume,
                status: HealthStatus::Unprotected,
                confidence: MatchConfidence::None,
                matched_repository_id: None,
                matched_snapshot_id: None,
                last_backup_time: None,
                backup_age_hours: None,
                restore_command: Some(
                    "RESTIC_REPOSITORY=\"/tmp/restic\" restic restore snap-1 --target ./restorix-restore-test --include \"/var/lib/docker/volumes/postgres_data/_data\""
                        .to_string(),
                ),
                reason: "No reliable snapshot path matched this Docker volume mountpoint."
                    .to_string(),
            },
            VolumeHealth {
                volume: unknown_volume,
                status: HealthStatus::Unknown,
                confidence: MatchConfidence::None,
                matched_repository_id: None,
                matched_snapshot_id: None,
                last_backup_time: None,
                backup_age_hours: None,
                restore_command: None,
                reason: "No enabled backup repositories are configured.".to_string(),
            },
        ],
        warnings: vec!["Loose matching is disabled.".to_string()],
        errors: Vec::new(),
    }
}
