import Foundation

enum MarkdownReportRenderer {
    static func render(
        _ result: ScanResult,
        language: AppLanguage,
        repositoryName: (String?) -> String
    ) -> String {
        var lines: [String] = []
        let summary = result.summary

        lines.append("# \(label(.report, language))")
        lines.append("\(label(.generatedAt, language)): \(summary.scannedAt)")
        lines.append("")
        lines.append("## \(label(.summary, language))")
        lines.append("- Docker \(label(.available, language)): \(yesNo(summary.dockerAvailable, language))")
        lines.append("- Docker \(label(.running, language)): \(yesNo(summary.dockerRunning, language))")
        lines.append("- Restic \(label(.available, language)): \(yesNo(summary.resticAvailable, language))")
        lines.append("- \(label(.totalContainers, language)): \(summary.totalContainers)")
        lines.append("- \(label(.totalVolumes, language)): \(summary.totalVolumes)")
        lines.append("- \(label(.protected, language)): \(summary.protectedCount)")
        lines.append("- \(label(.unprotected, language)): \(summary.unprotectedCount)")
        lines.append("- \(label(.stale, language)): \(summary.staleCount)")
        lines.append("- \(label(.unknown, language)): \(summary.unknownCount)")
        lines.append("- \(label(.errors, language)): \(summary.errorCount)")
        lines.append("")

        appendVolumeTable(
            title: label(.unprotectedVolumes, language),
            items: result.volumeHealth.filter { $0.status == .Unprotected },
            language: language,
            repositoryName: repositoryName,
            lines: &lines
        )
        appendVolumeTable(
            title: label(.staleVolumes, language),
            items: result.volumeHealth.filter { $0.status == .Stale },
            language: language,
            repositoryName: repositoryName,
            lines: &lines
        )
        appendVolumeTable(
            title: label(.unknownVolumes, language),
            items: result.volumeHealth.filter { $0.status == .Unknown },
            language: language,
            repositoryName: repositoryName,
            lines: &lines
        )
        appendVolumeTable(
            title: label(.protectedVolumes, language),
            items: result.volumeHealth.filter { $0.status == .Protected },
            language: language,
            repositoryName: repositoryName,
            lines: &lines
        )
        appendRestoreCommands(result.volumeHealth, language: language, lines: &lines)
        appendMessages(title: label(.warnings, language), messages: result.warnings, lines: &lines)
        appendMessages(title: label(.errors, language), messages: result.errors, lines: &lines)

        return lines.joined(separator: "\n") + "\n"
    }

    private static func appendVolumeTable(
        title: String,
        items: [VolumeHealth],
        language: AppLanguage,
        repositoryName: (String?) -> String,
        lines: inout [String]
    ) {
        guard !items.isEmpty else { return }
        lines.append("## \(title)")
        lines.append("| \(label(.volume, language)) | \(label(.status, language)) | \(label(.lastBackup, language)) | \(label(.repository, language)) | \(label(.reason, language)) |")
        lines.append("|---|---|---|---|---|")
        for item in items {
            lines.append(
                "| \(escape(item.volume.name)) | \(statusText(item.status, language)) | \(escape(item.lastBackupTime ?? label(.never, language))) | \(escape(repositoryName(item.matchedRepositoryId))) | \(escape(item.reason)) |"
            )
        }
        lines.append("")
    }

    private static func appendRestoreCommands(
        _ items: [VolumeHealth],
        language: AppLanguage,
        lines: inout [String]
    ) {
        let commands = items.filter { $0.restoreCommand != nil }
        guard !commands.isEmpty else { return }
        lines.append("## \(label(.restoreCommands, language))")
        for item in commands {
            lines.append("### \(item.volume.name)")
            lines.append("```bash")
            lines.append(item.restoreCommand ?? "")
            lines.append("```")
        }
        lines.append("")
    }

    private static func appendMessages(title: String, messages: [String], lines: inout [String]) {
        guard !messages.isEmpty else { return }
        lines.append("## \(title)")
        for message in messages {
            lines.append("- \(message)")
        }
        lines.append("")
    }

    private static func statusText(_ status: HealthStatus, _ language: AppLanguage) -> String {
        switch status {
        case .Protected:
            return label(.protected, language)
        case .Unprotected:
            return label(.unprotected, language)
        case .Stale:
            return label(.stale, language)
        case .Unknown:
            return label(.unknown, language)
        case .Error:
            return label(.errors, language)
        }
    }

    private static func yesNo(_ value: Bool, _ language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            return value ? "是" : "否"
        }
        return value ? "Yes" : "No"
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private static func label(_ label: Label, _ language: AppLanguage) -> String {
        switch (language, label) {
        case (.simplifiedChinese, .available): return "可用"
        case (.simplifiedChinese, .errors): return "错误"
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

    private enum Label {
        case available
        case errors
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
}
