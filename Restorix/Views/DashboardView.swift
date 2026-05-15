import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let error = app.lastError {
                    ErrorBanner(message: error)
                }

                ForEach(app.scanResult?.errors ?? [], id: \.self) { error in
                    ErrorBanner(message: error)
                }

                if let summary = app.scanResult?.summary {
                    HealthSummaryBanner(status: app.overallStatus, summary: summary)
                    summaryCards(summary)
                    environmentSection(summary)
                    nextStepsSection(summary)
                    riskSection
                    warningsSection
                } else {
                    EmptyStateView(
                        title: app.text(.noScanResults),
                        message: app.text(.noScanResultsMessage),
                        actionTitle: app.text(.scanNow)
                    ) {
                        Task { await app.scanNow() }
                    }
                    .frame(minHeight: 360)
                }
            }
            .padding(24)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.largeTitle.weight(.semibold))
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await app.scanNow() }
            } label: {
                Label(app.isScanning ? app.text(.scanning) : app.text(.scanNow), systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
            .disabled(app.isScanning)
        }
    }

    private var title: String {
        switch app.overallStatus {
        case .Protected:
            return app.text(.allProtected)
        case .Stale:
            return app.text(.backupNeedsAttention)
        case .Error:
            return app.text(.volumesAtRisk)
        case .Unknown:
            return app.text(.backupHealthUnknown)
        case .Unprotected:
            return app.text(.volumesAtRisk)
        }
    }

    private var subtitle: String {
        if let scannedAt = app.scanResult?.summary.scannedAt {
            return "\(app.text(.lastScan)): \(scannedAt)"
        }
        return app.text(.productSubtitle)
    }

    private func summaryCards(_ summary: ScanSummary) -> some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                StatusCard(title: app.text(.protected), value: summary.protectedCount, status: .Protected)
                StatusCard(title: app.text(.unprotected), value: summary.unprotectedCount, status: .Unprotected)
                StatusCard(title: app.text(.stale), value: summary.staleCount, status: .Stale)
                StatusCard(title: app.text(.unknown), value: summary.unknownCount, status: .Unknown)
            }
        }
    }

    private func environmentSection(_ summary: ScanSummary) -> some View {
        HStack(spacing: 12) {
            environmentPill(
                title: app.text(.docker),
                value: app.dockerStateText,
                icon: app.dockerStateIsHealthy ? "checkmark.circle.fill" : "xmark.circle.fill",
                color: app.dockerStateIsHealthy ? .green : .red
            )
            environmentPill(
                title: app.text(.restic),
                value: app.resticStateText,
                icon: summary.resticAvailable ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                color: summary.resticAvailable ? .green : .orange
            )
            environmentPill(
                title: app.text(.volumes),
                value: "\(summary.totalVolumes)",
                icon: "externaldrive.fill",
                color: .secondary
            )
            environmentPill(
                title: app.text(.containers),
                value: "\(summary.totalContainers)",
                icon: "shippingbox.fill",
                color: .secondary
            )
        }
    }

    private func environmentPill(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private var riskSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(app.text(.criticalIssues))
                .font(.headline)

            if app.riskyVolumes.isEmpty {
                Text(app.text(.noRiskyVolumes))
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            } else {
                ForEach(app.riskyVolumes.prefix(5)) { item in
                    HStack(spacing: 12) {
                        HealthBadge(status: item.status)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.volume.name)
                                .font(.body.weight(.medium))
                            Text(item.reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func nextStepsSection(_ summary: ScanSummary) -> some View {
        let steps = nextSteps(summary)
        return VStack(alignment: .leading, spacing: 10) {
            if !steps.isEmpty {
                Text(app.text(.nextSteps))
                    .font(.headline)
                ForEach(steps) { step in
                    NextStepRow(
                        title: step.title,
                        detail: step.detail,
                        systemImage: step.systemImage,
                        commandToCopy: step.commandToCopy
                    )
                }
            }
        }
    }

    private func nextSteps(_ summary: ScanSummary) -> [NextStep] {
        var steps: [NextStep] = []

        if !summary.dockerRunning {
            steps.append(NextStep(
                title: app.text(.dockerStartTitle),
                detail: app.text(.dockerStartDetail),
                systemImage: "play.circle",
                commandToCopy: nil
            ))
        }

        if !summary.resticAvailable {
            steps.append(NextStep(
                title: app.text(.installResticTitle),
                detail: app.text(.installResticDetail),
                systemImage: "terminal",
                commandToCopy: "brew install restic"
            ))
        }

        if app.repositories.isEmpty {
            steps.append(NextStep(
                title: app.text(.resticRepoAddTitle),
                detail: app.text(.resticRepoAddDetail),
                systemImage: "archivebox",
                commandToCopy: "restorix repo add --tool restic --name \"Local Restic\" --location \"/path/to/repo\" --password-env-key RESTIC_PASSWORD"
            ))
        }

        if summary.unknownCount > 0 && !app.repositories.isEmpty {
            steps.append(NextStep(
                title: app.text(.unknownReviewTitle),
                detail: app.text(.unknownReviewDetail),
                systemImage: "questionmark.circle",
                commandToCopy: nil
            ))
        }

        return steps
    }

    private var warningsSection: some View {
        let warnings = app.scanResult?.warnings ?? []
        return VStack(alignment: .leading, spacing: 8) {
            if !warnings.isEmpty {
                Text(app.text(.warnings))
                    .font(.headline)
                ForEach(warnings, id: \.self) { warning in
                    Text(warning)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

private struct NextStep: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let systemImage: String
    let commandToCopy: String?
}
