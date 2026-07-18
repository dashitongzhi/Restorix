enum MarkdownReportLabel {
    case available
    case errors
    case errorVolumes
    case generatedAt
    case lastBackup
    case never
    case protected
    case protectedVolumes
    case reason
    case report
    case repository
    case restoreCommands
    case running
    case stale
    case staleVolumes
    case status
    case summary
    case totalContainers
    case totalVolumes
    case unknown
    case unknownVolumes
    case unprotected
    case unprotectedVolumes
    case volume
    case warnings
}

enum MarkdownReportLocalization {
    static func text(_ label: MarkdownReportLabel, language: AppLanguage) -> String {
        switch (language, label) {
        case (.simplifiedChinese, .available): return "可用"
        case (.simplifiedChinese, .errors): return "错误"
        case (.simplifiedChinese, .errorVolumes): return "错误 Volumes"
        case (.simplifiedChinese, .generatedAt): return "生成时间"
        case (.simplifiedChinese, .lastBackup): return "最近备份"
        case (.simplifiedChinese, .never): return "从未"
        case (.simplifiedChinese, .protected): return "已保护"
        case (.simplifiedChinese, .protectedVolumes): return "已保护 Volumes"
        case (.simplifiedChinese, .reason): return "原因"
        case (.simplifiedChinese, .report): return "Restorix 报告"
        case (.simplifiedChinese, .repository): return "仓库"
        case (.simplifiedChinese, .restoreCommands): return "恢复命令"
        case (.simplifiedChinese, .running): return "运行中"
        case (.simplifiedChinese, .stale): return "已过期"
        case (.simplifiedChinese, .staleVolumes): return "已过期 Volumes"
        case (.simplifiedChinese, .status): return "状态"
        case (.simplifiedChinese, .summary): return "摘要"
        case (.simplifiedChinese, .totalContainers): return "容器总数"
        case (.simplifiedChinese, .totalVolumes): return "Volume 总数"
        case (.simplifiedChinese, .unknown): return "未知"
        case (.simplifiedChinese, .unknownVolumes): return "未知 Volumes"
        case (.simplifiedChinese, .unprotected): return "未保护"
        case (.simplifiedChinese, .unprotectedVolumes): return "未保护 Volumes"
        case (.simplifiedChinese, .volume): return "Volume"
        case (.simplifiedChinese, .warnings): return "警告"
        case (_, .available): return "available"
        case (_, .errors): return "Errors"
        case (_, .errorVolumes): return "Error Volumes"
        case (_, .generatedAt): return "Generated at"
        case (_, .lastBackup): return "Last Backup"
        case (_, .never): return "Never"
        case (_, .protected): return "Protected"
        case (_, .protectedVolumes): return "Protected Volumes"
        case (_, .reason): return "Reason"
        case (_, .report): return "Restorix Report"
        case (_, .repository): return "Repository"
        case (_, .restoreCommands): return "Restore Commands"
        case (_, .running): return "running"
        case (_, .stale): return "Stale"
        case (_, .staleVolumes): return "Stale Volumes"
        case (_, .status): return "Status"
        case (_, .summary): return "Summary"
        case (_, .totalContainers): return "Total containers"
        case (_, .totalVolumes): return "Total volumes"
        case (_, .unknown): return "Unknown"
        case (_, .unknownVolumes): return "Unknown Volumes"
        case (_, .unprotected): return "Unprotected"
        case (_, .unprotectedVolumes): return "Unprotected Volumes"
        case (_, .volume): return "Volume"
        case (_, .warnings): return "Warnings"
        }
    }
}
