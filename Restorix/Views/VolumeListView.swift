import SwiftUI

struct VolumeListView: View {
    @EnvironmentObject private var app: AppViewModel
    @State private var selectedVolume: VolumeHealth?
    @State private var statusFilter: VolumeStatusFilter = .all
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(app.text(.volumeHealth))
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    Task { await app.scanNow() }
                } label: {
                    Label(app.text(.scanNow), systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(app.isScanning)
            }

            if let health = app.scanResult?.volumeHealth, !health.isEmpty {
                filterBar
                let visibleHealth = filteredHealth(health)
                if visibleHealth.isEmpty {
                    EmptyStateView(
                        title: emptyFilterTitle,
                        message: emptyFilterMessage,
                        actionTitle: nil,
                        action: nil
                    )
                } else {
                    ScrollView {
                        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
                            GridRow {
                                tableHeader(app.text(.volume))
                                tableHeader(app.text(.status))
                                tableHeader(app.text(.lastBackup))
                                tableHeader(app.text(.repository))
                                tableHeader(app.text(.reason))
                                tableHeader("")
                            }
                            Divider()
                                .gridCellColumns(6)
                            ForEach(visibleHealth) { item in
                                VolumeHealthRow(item: item)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedVolume = item
                                    }
                                Divider()
                                    .gridCellColumns(6)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            } else {
                EmptyStateView(
                    title: app.text(.noVolumesFound),
                    message: app.text(.noVolumesFoundMessage),
                    actionTitle: app.text(.scanNow)
                ) {
                    Task { await app.scanNow() }
                }
            }
        }
        .padding(24)
        .sheet(item: $selectedVolume) { item in
            VolumeDetailView(item: item)
                .environmentObject(app)
                .frame(width: 680)
        }
    }

    private func tableHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            Picker("", selection: $statusFilter) {
                ForEach(VolumeStatusFilter.allCases) { filter in
                    Text(filter.title(app: app)).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 520)

            Spacer()

            TextField(searchPrompt, text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
        }
    }

    private func filteredHealth(_ health: [VolumeHealth]) -> [VolumeHealth] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return health.filter { item in
            statusFilter.matches(item.status) && (query.isEmpty || matches(item, query: query))
        }
    }

    private func matches(_ item: VolumeHealth, query: String) -> Bool {
        [
            item.volume.name,
            item.volume.mountpoint,
            app.repositoryDisplayName(for: item.matchedRepositoryId),
            item.reason,
            item.lastBackupTime ?? ""
        ]
        .contains { $0.lowercased().contains(query) }
    }

    private var searchPrompt: String {
        app.language == .simplifiedChinese ? "搜索 volume、路径、仓库" : "Search volume, path, repository"
    }

    private var emptyFilterTitle: String {
        app.language == .simplifiedChinese ? "没有匹配的 volumes" : "No matching volumes"
    }

    private var emptyFilterMessage: String {
        app.language == .simplifiedChinese ? "调整筛选条件或搜索内容。" : "Adjust the filter or search text."
    }
}

private enum VolumeStatusFilter: String, CaseIterable, Identifiable {
    case all
    case atRisk
    case protected
    case stale
    case unknown

    var id: String { rawValue }

    func title(app: AppViewModel) -> String {
        switch self {
        case .all:
            return app.language == .simplifiedChinese ? "全部" : "All"
        case .atRisk:
            return app.language == .simplifiedChinese ? "风险" : "At Risk"
        case .protected:
            return app.text(.protected)
        case .stale:
            return app.text(.stale)
        case .unknown:
            return app.text(.unknown)
        }
    }

    func matches(_ status: HealthStatus) -> Bool {
        switch self {
        case .all:
            return true
        case .atRisk:
            return status == .Unprotected || status == .Stale || status == .Error
        case .protected:
            return status == .Protected
        case .stale:
            return status == .Stale
        case .unknown:
            return status == .Unknown
        }
    }
}
