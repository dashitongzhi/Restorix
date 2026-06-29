import Foundation

enum AppIconChoice: String, CaseIterable, Identifiable {
    case `default`
    case dimensional
    case glass
    case neon

    static let userDefaultsKey = "app.iconChoice"

    var id: String { rawValue }

    var assetName: String {
        switch self {
        case .default:
            return "RestorixIconDefault"
        case .dimensional:
            return "RestorixIconDimensional"
        case .glass:
            return "RestorixIconGlass"
        case .neon:
            return "RestorixIconNeon"
        }
    }

    var titleKey: L10nKey {
        switch self {
        case .default:
            return .appIconDefault
        case .dimensional:
            return .appIconDimensional
        case .glass:
            return .appIconGlass
        case .neon:
            return .appIconNeon
        }
    }
}
