import SwiftUI

struct StatusCard: View {
    @EnvironmentObject private var app: AppViewModel
    let title: String
    let value: Int
    let status: HealthStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
            Text(app.text(.volumes))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }

    private var color: Color {
        switch status {
        case .Protected:
            return .green
        case .Unprotected, .Error:
            return .red
        case .Stale:
            return .orange
        case .Unknown:
            return .secondary
        }
    }
}
