import SwiftUI

struct VolumeHealthRow: View {
    @EnvironmentObject private var app: AppViewModel
    let item: VolumeHealth
    @State private var copied = false

    var body: some View {
        GridRow {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.volume.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(item.volume.mountpoint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HealthBadge(status: item.status)

            Text(item.lastBackupTime ?? app.text(.never))
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(item.matchedRepositoryId ?? app.text(.none))
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(item.reason)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Button {
                if let command = item.restoreCommand {
                    Pasteboard.copy(command)
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.4))
                        copied = false
                    }
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(copied ? .green : .primary)
            }
            .buttonStyle(.borderless)
            .disabled(item.restoreCommand == nil)
            .help(copied ? app.text(.copied) : app.text(.copyRestoreCommand))
        }
    }
}
