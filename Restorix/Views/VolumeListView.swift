import SwiftUI

struct VolumeListView: View {
    @EnvironmentObject private var app: AppViewModel
    @State private var selectedVolume: VolumeHealth?

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
                        ForEach(health) { item in
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
}
