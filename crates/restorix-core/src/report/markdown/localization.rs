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

pub(super) fn localized_message(language: ReportLanguage, value: &str) -> String {
    if language == ReportLanguage::English {
        return value.to_string();
    }

    match value {
        "Docker metadata is incomplete: volume mountpoint is empty." => {
            "Docker 元数据不完整：volume 挂载路径为空。".to_string()
        }
        "No enabled backup repositories are configured." => {
            "还没有配置已启用的备份仓库。".to_string()
        }
        "No reliable snapshot path matched this Docker volume mountpoint." => {
            "没有可靠的 snapshot 路径匹配这个 Docker volume 挂载点。".to_string()
        }
        "Only a volume-name match was found. Enable loose matching to treat this as protected." => {
            "只找到了 volume 名称匹配。启用宽松匹配后才会把它视为已保护。".to_string()
        }
        "A recent restic snapshot matches this Docker volume mountpoint." => {
            "最近的 restic snapshot 匹配这个 Docker volume 挂载点。".to_string()
        }
        "A matching snapshot was found, but its timestamp could not be parsed." => {
            "找到了匹配的 snapshot，但无法解析它的时间戳。".to_string()
        }
        "A matching snapshot has a future timestamp, so backup freshness is unknown." => {
            "匹配的 snapshot 时间戳在未来，因此无法判断备份是否新鲜。".to_string()
        }
        "At least one repository scan failed, so Restorix cannot confirm this volume is unprotected." => {
            "至少一个仓库扫描失败，因此 Restorix 无法确认这个 volume 未受保护。".to_string()
        }
        "An enabled repository has no expected snapshot hostname, so Restorix cannot prove host-specific backup coverage." => {
            "已启用仓库未配置预期快照主机名，因此 Restorix 无法证明此主机的备份覆盖。".to_string()
        }
        "Repository scan failed, so Restorix cannot determine backup health for this volume." => {
            "仓库扫描失败，因此 Restorix 无法判断这个 volume 的备份健康状态。".to_string()
        }
        "Restic is required by at least one enabled repository but is not installed." => {
            "至少一个已启用仓库需要 restic，但当前没有安装 restic。".to_string()
        }
        "Restic is not installed. Install restic with Homebrew: brew install restic" => {
            "未安装 restic。可以使用 Homebrew 安装：brew install restic".to_string()
        }
        "No enabled backup repositories are configured, so Restorix can list Docker volumes but cannot verify backups." => {
            "还没有配置已启用的备份仓库，因此 Restorix 可以列出 Docker volumes，但无法验证备份。".to_string()
        }
        "Loose matching is disabled." => "宽松匹配已关闭。".to_string(),
        _ => localized_dynamic_message(value),
    }
}

fn localized_dynamic_message(value: &str) -> String {
    if let Some(hours) = value
        .strip_prefix("Latest matching snapshot is older than the stale threshold (")
        .and_then(|rest| rest.strip_suffix(" hours)."))
    {
        return format!("最新匹配的 snapshot 已超过过期阈值（{hours} 小时）。");
    }

    if let Some(volumes) = value
        .strip_prefix("These volumes look stateful or database-backed: ")
        .and_then(|rest| {
            rest.strip_suffix(". File-level snapshots may still need app-aware dumps or a stopped container for consistent restores.")
        })
    {
        return format!(
            "这些 volumes 看起来是有状态服务或数据库数据：{volumes}。文件级 snapshots 可能仍需要应用级 dump，或在容器停止后创建，才能保证恢复一致性。"
        );
    }

    value.to_string()
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
