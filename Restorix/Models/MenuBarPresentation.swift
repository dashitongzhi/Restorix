import Foundation

enum ScanPresentation {
    static func overallStatus(for result: ScanResult?) -> HealthStatus {
        guard let result else { return .Unknown }
        let summary = result.summary
        if !result.errors.isEmpty || summary.errorCount > 0 || summary.unprotectedCount > 0 {
            return .Error
        }
        if summary.staleCount > 0 || summary.unknownCount > 0 {
            return .Stale
        }
        return .Protected
    }
}

struct MenuBarPresentation {
    let result: ScanResult?
    let isScanning: Bool
    let language: AppLanguage
    var now: Date = Date()

    var statusBarTitle: String {
        guard let summary = result?.summary else {
            return isScanning ? "Restorix ..." : "Restorix"
        }
        if summary.errorCount > 0 || summary.unprotectedCount > 0 {
            return "Restorix \(summary.unprotectedCount + summary.errorCount)!"
        }
        if summary.staleCount > 0 { return "Restorix \(summary.staleCount)" }
        if summary.unknownCount > 0 { return "Restorix \(summary.unknownCount)?" }
        return "Restorix OK"
    }

    var overallLine: String {
        switch ScanPresentation.overallStatus(for: result) {
        case .Protected:
            return text(.healthAllProtected)
        case .Stale:
            return text(.healthNeedsReview)
        case .Unprotected, .Error:
            return text(.healthAtRisk)
        case .Unknown:
            return text(.healthUnknown)
        }
    }

    var statusLine: String {
        guard let summary = result?.summary else { return text(.statusNotScanned) }
        return "\(text(.statusLine)): \(summary.protectedCount) \(text(.protected)), \(summary.unprotectedCount) \(text(.unprotected)), \(summary.staleCount) \(text(.stale)), \(summary.unknownCount) \(text(.unknown))"
    }

    var lastScanLine: String {
        guard let summary = result?.summary else { return "\(text(.lastScan)): \(text(.never))" }
        return "\(text(.lastScan)): \(relativeDate(summary.scannedAt))"
    }

    var tooltip: String {
        guard let summary = result?.summary else { return text(.statusNotScanned) }
        return "\(overallLine) - \(summary.totalVolumes) \(text(.volumes))"
    }

    var riskyVolumes: [VolumeHealth] {
        result.map(VolumeRiskPolicy.itemsRequiringAttention(in:)) ?? []
    }

    func statusText(_ status: HealthStatus) -> String {
        switch status {
        case .Protected: return text(.protected)
        case .Unprotected: return text(.unprotected)
        case .Stale: return text(.stale)
        case .Unknown: return text(.unknown)
        case .Error: return text(.error)
        }
    }

    private func text(_ key: L10nKey) -> String {
        AppStrings.text(key, language: language)
    }

    private func relativeDate(_ value: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
        guard let date else { return value }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .short
        return relative.localizedString(for: date, relativeTo: now)
    }
}
