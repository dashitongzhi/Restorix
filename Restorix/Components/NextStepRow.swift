import SwiftUI

struct NextStepRow: View {
    @EnvironmentObject private var app: AppViewModel
    let title: String
    let detail: String
    let systemImage: String
    let actionTitle: String?
    let commandToCopy: String?
    let action: () -> Void

    @State private var copied = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer()

            HStack(spacing: 8) {
                if let actionTitle {
                    Button(actionTitle, action: action)
                        .buttonStyle(.bordered)
                }

                if let commandToCopy {
                    Button {
                        Pasteboard.copy(commandToCopy)
                        copied = true
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help(copied ? app.text(.copied) : app.text(.copyCommand))
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
    }
}
