#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ReportLanguage {
    English,
    SimplifiedChinese,
}

impl ReportLanguage {
    pub fn from_code(value: &str) -> Self {
        match value.to_ascii_lowercase().as_str() {
            "zh" | "zh-hans" | "zh_cn" | "zh-cn" | "chinese" => Self::SimplifiedChinese,
            _ => Self::English,
        }
    }
}

pub(super) fn yes_no(language: ReportLanguage, value: bool) -> &'static str {
    match (language, value) {
        (ReportLanguage::SimplifiedChinese, true) => "是",
        (ReportLanguage::SimplifiedChinese, false) => "否",
        (_, true) => "Yes",
        (_, false) => "No",
    }
}

pub(super) fn localized_diagnostic(language: ReportLanguage, diagnostic: &Diagnostic) -> String {
    if language == ReportLanguage::English {
        return diagnostic.message.clone();
    }

    match diagnostic.code {
        DiagnosticCode::VolumeMountpointMissing => "Docker 元数据不完整：volume 挂载路径为空。".to_string(),
        DiagnosticCode::NoEnabledRepositories => "还没有配置已启用的备份仓库。".to_string(),
        DiagnosticCode::NoSnapshotMatch => "没有可靠的 snapshot 路径匹配这个 Docker volume 挂载点。".to_string(),
        DiagnosticCode::VolumeNameMatchOnly => "只找到了 volume 名称匹配。启用宽松匹配后才会把它视为已保护。".to_string(),
        DiagnosticCode::RecentSnapshot => "最近的 restic snapshot 匹配这个 Docker volume 挂载点。".to_string(),
        DiagnosticCode::SnapshotTimeUnparseable => "找到了匹配的 snapshot，但无法解析它的时间戳。".to_string(),
        DiagnosticCode::FutureSnapshot => "匹配的 snapshot 时间戳在未来，因此无法判断备份是否新鲜。".to_string(),
        DiagnosticCode::RepositoryCoverageUnknown => "至少一个仓库扫描失败，因此 Restorix 无法确认这个 volume 未受保护。".to_string(),
        DiagnosticCode::MissingExpectedHostname => "已启用仓库未配置预期快照主机名，因此 Restorix 无法证明此主机的备份覆盖。".to_string(),
        DiagnosticCode::ResticRequiredMissing => "至少一个已启用仓库需要 restic，但当前没有安装 restic。".to_string(),
        DiagnosticCode::ResticUnavailable => "未安装 restic。可以使用 Homebrew 安装：brew install restic".to_string(),
        DiagnosticCode::BackupVerificationUnconfigured => "还没有配置已启用的备份仓库，因此 Restorix 可以列出 Docker volumes，但无法验证备份。".to_string(),
        DiagnosticCode::StaleSnapshot => format!(
            "最新匹配的 snapshot 已超过过期阈值（{} 小时）。",
            diagnostic.context.hours.unwrap_or_default()
        ),
        DiagnosticCode::StatefulVolumes => format!(
            "这些 volumes 看起来是有状态服务或数据库数据：{}。文件级 snapshots 可能仍需要应用级 dump，或在容器停止后创建，才能保证恢复一致性。",
            diagnostic.context.volumes.join(", ")
        ),
        DiagnosticCode::ChildPathOnly => "snapshot 只覆盖了这个 Docker volume 内的子路径，因此无法确认整个 volume 已受保护。".to_string(),
        DiagnosticCode::UnreliableSnapshotMatch => "snapshot 覆盖关系不够可靠，无法判断整个 volume 的保护状态。".to_string(),
        DiagnosticCode::RepositoryScanFailed => match (
            diagnostic.context.repository.as_deref(),
            diagnostic.context.detail.as_deref(),
        ) {
            (Some(repository), Some(detail)) => format!("仓库 {repository} 扫描失败：{detail}"),
            _ => diagnostic.message.clone(),
        },
        DiagnosticCode::LooseMatchingDisabled => "宽松匹配已关闭。".to_string(),
        _ => diagnostic.message.clone(),
    }
}

#[derive(Debug, Clone, Copy)]
pub(super) enum Label {
    AgeHours,
    Available,
    Errors,
    ErrorVolumes,
    GeneratedAt,
    LastBackup,
    Mountpoint,
    Protected,
    ProtectedVolumes,
    Reason,
    Report,
    Repository,
    RestoreCommands,
    Running,
    Stale,
    StaleVolumes,
    Summary,
    TotalContainers,
    TotalVolumes,
    Unknown,
    UnknownVolumes,
    Unprotected,
    UnprotectedVolumes,
    Volume,
    Warnings,
}

pub(super) fn label(language: ReportLanguage, label: Label) -> &'static str {
    match (language, label) {
        (ReportLanguage::English, Label::AgeHours) => "Age Hours",
        (ReportLanguage::English, Label::Available) => "available",
        (ReportLanguage::English, Label::Errors) => "Errors",
        (ReportLanguage::English, Label::ErrorVolumes) => "Error Volumes",
        (ReportLanguage::English, Label::GeneratedAt) => "Generated at",
        (ReportLanguage::English, Label::LastBackup) => "Last Backup",
        (ReportLanguage::English, Label::Mountpoint) => "Mountpoint",
        (ReportLanguage::English, Label::Protected) => "Protected",
        (ReportLanguage::English, Label::ProtectedVolumes) => "Protected Volumes",
        (ReportLanguage::English, Label::Reason) => "Reason",
        (ReportLanguage::English, Label::Report) => "Restorix Report",
        (ReportLanguage::English, Label::Repository) => "Repository",
        (ReportLanguage::English, Label::RestoreCommands) => "Restore Commands",
        (ReportLanguage::English, Label::Running) => "running",
        (ReportLanguage::English, Label::Stale) => "Stale",
        (ReportLanguage::English, Label::StaleVolumes) => "Stale Volumes",
        (ReportLanguage::English, Label::Summary) => "Summary",
        (ReportLanguage::English, Label::TotalContainers) => "Total containers",
        (ReportLanguage::English, Label::TotalVolumes) => "Total volumes",
        (ReportLanguage::English, Label::Unknown) => "Unknown",
        (ReportLanguage::English, Label::UnknownVolumes) => "Unknown Volumes",
        (ReportLanguage::English, Label::Unprotected) => "Unprotected",
        (ReportLanguage::English, Label::UnprotectedVolumes) => "Unprotected Volumes",
        (ReportLanguage::English, Label::Volume) => "Volume",
        (ReportLanguage::English, Label::Warnings) => "Warnings",
        (ReportLanguage::SimplifiedChinese, Label::AgeHours) => "小时",
        (ReportLanguage::SimplifiedChinese, Label::Available) => "可用",
        (ReportLanguage::SimplifiedChinese, Label::Errors) => "错误",
        (ReportLanguage::SimplifiedChinese, Label::ErrorVolumes) => "错误 Volumes",
        (ReportLanguage::SimplifiedChinese, Label::GeneratedAt) => "生成时间",
        (ReportLanguage::SimplifiedChinese, Label::LastBackup) => "最近备份",
        (ReportLanguage::SimplifiedChinese, Label::Mountpoint) => "挂载路径",
        (ReportLanguage::SimplifiedChinese, Label::Protected) => "已保护",
        (ReportLanguage::SimplifiedChinese, Label::ProtectedVolumes) => "已保护 Volumes",
        (ReportLanguage::SimplifiedChinese, Label::Reason) => "原因",
        (ReportLanguage::SimplifiedChinese, Label::Report) => "Restorix 报告",
        (ReportLanguage::SimplifiedChinese, Label::Repository) => "仓库",
        (ReportLanguage::SimplifiedChinese, Label::RestoreCommands) => "恢复命令",
        (ReportLanguage::SimplifiedChinese, Label::Running) => "运行中",
        (ReportLanguage::SimplifiedChinese, Label::Stale) => "已过期",
        (ReportLanguage::SimplifiedChinese, Label::StaleVolumes) => "已过期 Volumes",
        (ReportLanguage::SimplifiedChinese, Label::Summary) => "摘要",
        (ReportLanguage::SimplifiedChinese, Label::TotalContainers) => "容器总数",
        (ReportLanguage::SimplifiedChinese, Label::TotalVolumes) => "Volume 总数",
        (ReportLanguage::SimplifiedChinese, Label::Unknown) => "未知",
        (ReportLanguage::SimplifiedChinese, Label::UnknownVolumes) => "未知 Volumes",
        (ReportLanguage::SimplifiedChinese, Label::Unprotected) => "未保护",
        (ReportLanguage::SimplifiedChinese, Label::UnprotectedVolumes) => "未保护 Volumes",
        (ReportLanguage::SimplifiedChinese, Label::Volume) => "Volume",
        (ReportLanguage::SimplifiedChinese, Label::Warnings) => "警告",
    }
}
use crate::diagnostic::{Diagnostic, DiagnosticCode};
