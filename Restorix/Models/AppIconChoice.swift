import AppKit
import Foundation

enum AppIconChoice: String, CaseIterable, Identifiable {
    case `default`
    case orbitCheck
    case vaultSeal
    case snapshotLayers
    case timeCapsule
    case integrityPrism
    case signalArchive
    case minimalRibbon
    case checksumWave
    case dimensional
    case glass
    case neon

    static let userDefaultsKey = "app.iconChoice"

    static let chooserChoices: [AppIconChoice] = [
        .default,
        .orbitCheck,
        .vaultSeal,
        .snapshotLayers,
        .timeCapsule,
        .integrityPrism,
        .signalArchive,
        .minimalRibbon,
        .checksumWave,
        .dimensional,
        .glass,
        .neon,
    ]

    var id: String { rawValue }

    var assetName: String {
        switch self {
        case .default:
            return "RestorixIconDefault"
        case .orbitCheck:
            return "RestorixIconOrbitCheck"
        case .vaultSeal:
            return "RestorixIconVaultSeal"
        case .snapshotLayers:
            return "RestorixIconSnapshotLayers"
        case .timeCapsule:
            return "RestorixIconTimeCapsule"
        case .integrityPrism:
            return "RestorixIconIntegrityPrism"
        case .signalArchive:
            return "RestorixIconSignalArchive"
        case .minimalRibbon:
            return "RestorixIconMinimalRibbon"
        case .checksumWave:
            return "RestorixIconChecksumWave"
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
        case .orbitCheck:
            return .appIconOrbitCheck
        case .vaultSeal:
            return .appIconVaultSeal
        case .snapshotLayers:
            return .appIconSnapshotLayers
        case .timeCapsule:
            return .appIconTimeCapsule
        case .integrityPrism:
            return .appIconIntegrityPrism
        case .signalArchive:
            return .appIconSignalArchive
        case .minimalRibbon:
            return .appIconMinimalRibbon
        case .checksumWave:
            return .appIconChecksumWave
        case .dimensional:
            return .appIconDimensional
        case .glass:
            return .appIconGlass
        case .neon:
            return .appIconNeon
        }
    }

    var image: NSImage? {
        NSImage(named: NSImage.Name(assetName))
    }

    static func stored(in defaults: UserDefaults = .standard) -> AppIconChoice {
        guard let storedValue = defaults.string(forKey: userDefaultsKey) else {
            return .default
        }

        guard let choice = AppIconChoice(rawValue: storedValue) else {
            defaults.removeObject(forKey: userDefaultsKey)
            return .default
        }

        return choice.image == nil ? .default : choice
    }

    func save(in defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.userDefaultsKey)
    }
}
