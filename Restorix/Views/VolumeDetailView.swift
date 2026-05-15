import SwiftUI

struct VolumeDetailView: View {
    @EnvironmentObject private var app: AppViewModel
    let item: VolumeHealth
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.volume.name)
                        .font(.title3.weight(.semibold))
                    Text(item.volume.mountpoint)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer()
                HealthBadge(status: item.status)
            }

            Text(item.reason)
                .font(.callout)
                .foregroundStyle(.secondary)

            if let command = item.restoreCommand {
                VStack(alignment: .leading, spacing: 8) {
                    Text(app.text(.safeRestoreCommand))
                        .font(.headline)
                    Text(command)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))

                    Button {
                        Pasteboard.copy(command)
                        copied = true
                    } label: {
                        Label(copied ? app.text(.copied) : app.text(.copyRestoreCommand), systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(20)
    }
}
