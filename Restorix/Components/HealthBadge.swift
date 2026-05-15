import SwiftUI

struct HealthBadge: View {
    @EnvironmentObject private var app: AppViewModel
    let status: HealthStatus

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var title: String {
        switch status {
        case .Protected:
            return app.text(.protected)
        case .Unprotected:
            return app.text(.unprotected)
        case .Stale:
            return app.text(.stale)
        case .Unknown:
            return app.text(.unknown)
        case .Error:
            return app.text(.error)
        }
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

    private var systemImage: String {
        switch status {
        case .Protected:
            return "checkmark.shield"
        case .Unprotected:
            return "exclamationmark.shield"
        case .Stale:
            return "clock.badge.exclamationmark"
        case .Unknown:
            return "questionmark.circle"
        case .Error:
            return "xmark.octagon"
        }
    }
}
