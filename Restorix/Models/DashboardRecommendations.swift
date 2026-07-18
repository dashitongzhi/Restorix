import AppKit

enum DashboardAction: String, Identifiable {
    case addRepository
    case openDocker
    case openSettings
    case openVolumes

    var id: String { rawValue }
}

struct DashboardRecommendation: Identifiable {
    let action: DashboardAction
    let title: String
    let detail: String
    let systemImage: String
    let actionTitle: String
    let commandToCopy: String?

    var id: DashboardAction { action }
}

enum DashboardRecommendationBuilder {
    static func build(
        summary: ScanSummary,
        repositoriesEmpty: Bool,
        text: (L10nKey) -> String
    ) -> [DashboardRecommendation] {
        var recommendations: [DashboardRecommendation] = []

        if !summary.dockerRunning {
            recommendations.append(DashboardRecommendation(
                action: .openDocker,
                title: text(.dockerStartTitle),
                detail: text(.dockerStartDetail),
                systemImage: "play.circle",
                actionTitle: text(.openDocker),
                commandToCopy: nil
            ))
        }

        if !summary.resticAvailable {
            recommendations.append(DashboardRecommendation(
                action: .openSettings,
                title: text(.installResticTitle),
                detail: text(.installResticDetail),
                systemImage: "terminal",
                actionTitle: text(.configureCLI),
                commandToCopy: "brew install restic"
            ))
        }

        if repositoriesEmpty {
            recommendations.append(DashboardRecommendation(
                action: .addRepository,
                title: text(.resticRepoAddTitle),
                detail: text(.resticRepoAddDetail),
                systemImage: "archivebox",
                actionTitle: text(.addRepository),
                commandToCopy: "restorix repo add --tool restic --name \"Local Restic\" --location \"/path/to/repo\" --password-env-key RESTIC_PASSWORD"
            ))
        }

        if summary.unknownCount > 0 && !repositoriesEmpty {
            recommendations.append(DashboardRecommendation(
                action: .openVolumes,
                title: text(.unknownReviewTitle),
                detail: text(.unknownReviewDetail),
                systemImage: "questionmark.circle",
                actionTitle: text(.reviewVolumes),
                commandToCopy: nil
            ))
        }

        return recommendations
    }
}

@MainActor
enum DashboardActionHandler {
    static func perform(_ action: DashboardAction, app: AppViewModel) {
        switch action {
        case .addRepository:
            app.beginAddingRepository()
        case .openSettings:
            WindowManager.openSettings()
        case .openVolumes:
            app.selectedSidebarItem = .volumes
        case .openDocker:
            openDockerApp()
        }
    }

    private static func openDockerApp() {
        for bundleIdentifier in ["com.docker.docker", "dev.orbstack.OrbStack"] {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
                continue
            }
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
            return
        }
        WindowManager.openSettings()
    }
}
