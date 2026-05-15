import SwiftUI

struct HealthSummaryBanner: View {
    @EnvironmentObject private var app: AppViewModel
    let status: HealthStatus
    let summary: ScanSummary

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(16)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }

    private var title: String {
        switch status {
        case .Protected:
            return app.language == .simplifiedChinese ? "你的 Docker volumes 看起来已被保护" : "Your Docker volumes look protected"
        case .Stale:
            return app.language == .simplifiedChinese ? "部分备份检查需要关注" : "Some backup checks need attention"
        case .Error, .Unprotected:
            return app.language == .simplifiedChinese ? "Restorix 发现有风险的 volumes" : "Restorix found volumes at risk"
        case .Unknown:
            return app.language == .simplifiedChinese ? "运行扫描以确认备份健康状态" : "Run a scan to confirm backup health"
        }
    }

    private var message: String {
        switch status {
        case .Protected:
            if app.language == .simplifiedChinese {
                return "\(summary.protectedCount) 个 volume 匹配到最近的 restic snapshot。"
            }
            return "\(summary.protectedCount) volume\(summary.protectedCount == 1 ? "" : "s") matched recent restic snapshots."
        case .Stale:
            if app.language == .simplifiedChinese {
                return "\(summary.staleCount) 个已过期，\(summary.unknownCount) 个未知，需要检查。"
            }
            return "\(summary.staleCount) stale and \(summary.unknownCount) unknown volume\(summary.staleCount + summary.unknownCount == 1 ? "" : "s") need review."
        case .Error, .Unprotected:
            if app.language == .simplifiedChinese {
                return "\(summary.unprotectedCount) 个未保护，\(summary.errorCount) 个错误；信任恢复前需要处理。"
            }
            return "\(summary.unprotectedCount) unprotected and \(summary.errorCount) error volume\(summary.unprotectedCount + summary.errorCount == 1 ? "" : "s") need action before you trust recovery."
        case .Unknown:
            return app.language == .simplifiedChinese ? "Restorix 还没有确认可靠的备份状态。" : "Restorix has not confirmed a reliable backup state yet."
        }
    }

    private var color: Color {
        switch status {
        case .Protected:
            return .green
        case .Stale:
            return .orange
        case .Unprotected, .Error:
            return .red
        case .Unknown:
            return .secondary
        }
    }

    private var icon: String {
        switch status {
        case .Protected:
            return "checkmark.shield.fill"
        case .Stale:
            return "clock.badge.exclamationmark.fill"
        case .Unprotected, .Error:
            return "exclamationmark.shield.fill"
        case .Unknown:
            return "questionmark.circle.fill"
        }
    }
}
