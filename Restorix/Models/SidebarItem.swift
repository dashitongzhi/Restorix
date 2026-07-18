import Foundation

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case volumes = "Volumes"
    case repositories = "Repositories"
    case reports = "Reports"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .dashboard:
            return "gauge.with.dots.needle.67percent"
        case .volumes:
            return "externaldrive"
        case .repositories:
            return "archivebox"
        case .reports:
            return "doc.text"
        case .settings:
            return "gearshape"
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .dashboard:
            return AppStrings.text(.dashboard, language: language)
        case .volumes:
            return AppStrings.text(.volumes, language: language)
        case .repositories:
            return AppStrings.text(.repositories, language: language)
        case .reports:
            return AppStrings.text(.reports, language: language)
        case .settings:
            return AppStrings.text(.settings, language: language)
        }
    }
}
