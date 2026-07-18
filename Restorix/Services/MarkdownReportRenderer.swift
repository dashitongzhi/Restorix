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
            title: label(.errorVolumes, language),
            items: result.volumeHealth.filter { $0.status == .Error },
            language: language,
            repositoryName: repositoryName,
            lines: &lines
        )
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
        appendMessages(
            title: label(.warnings, language),
            messages: result.warnings,
            language: language,
            lines: &lines
        )
        appendMessages(
            title: label(.errors, language),
            messages: result.errors,
            language: language,
            lines: &lines
        )

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
                "| \(escape(item.volume.name)) | \(statusText(item.status, language)) | \(escape(item.lastBackupTime ?? label(.never, language))) | \(escape(repositoryName(item.matchedRepositoryId))) | \(escape(item.reason.localizedMessage(language: language))) |"
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

    private static func appendMessages(
        title: String,
        messages: [Diagnostic],
        language: AppLanguage,
        lines: inout [String]
    ) {
        guard !messages.isEmpty else { return }
        lines.append("## \(title)")
        for message in messages {
            lines.append("- \(message.localizedMessage(language: language))")
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

    private static func label(_ label: MarkdownReportLabel, _ language: AppLanguage) -> String {
        MarkdownReportLocalization.text(label, language: language)
    }
}
