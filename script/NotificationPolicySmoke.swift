import Foundation

@main
struct NotificationPolicySmoke {
    static func main() throws {
        let result = scanResult(statuses: [.Protected, .Unknown, .Stale])
        let now = Date(timeIntervalSince1970: 1_000_000)

        let plan = NotificationPolicy.plan(
            for: result,
            enabled: true,
            language: .english,
            lastSentAt: nil,
            now: now
        )
        try require(plan?.body.contains("2 Docker volumes need attention") == true, "risk selection")
        try require(plan?.key.contains("unknown-Unknown") == true, "unknown risk key")

        let throttled = NotificationPolicy.plan(
            for: result,
            enabled: true,
            language: .english,
            lastSentAt: now.addingTimeInterval(-60),
            now: now
        )
        try require(throttled == nil, "24-hour throttle")

        let disabled = NotificationPolicy.plan(
            for: result,
            enabled: false,
            language: .english,
            lastSentAt: nil,
            now: now
        )
        try require(disabled == nil, "disabled notifications")

        print("NotificationPolicy smoke passed")
    }

    private static func scanResult(statuses: [HealthStatus]) -> ScanResult {
        let health = statuses.enumerated().map { index, status in
            VolumeHealth(
                volume: DockerVolume(
                    name: status.rawValue.lowercased(),
                    driver: "local",
                    mountpoint: "/tmp/\(index)",
                    labels: []
                ),
                status: status,
                confidence: .None,
                matchedRepositoryId: nil,
                matchedSnapshotId: nil,
                lastBackupTime: nil,
                backupAgeHours: nil,
                restoreCommand: nil,
                reason: Diagnostic(
                    code: .generic,
                    context: DiagnosticContext(),
                    message: "fixture"
                )
            )
        }
        return ScanResult(
            summary: ScanSummary(
                scannedAt: "2026-07-19T00:00:00Z",
                platform: .MacOS,
                dockerAvailable: true,
                dockerRunning: true,
                resticAvailable: true,
                totalContainers: 0,
                totalVolumes: health.count,
                protectedCount: 1,
                unprotectedCount: 0,
                staleCount: 1,
                unknownCount: 1,
                errorCount: 0
            ),
            containers: [],
            volumes: health.map(\.volume),
            repositories: [],
            snapshots: [],
            volumeHealth: health,
            warnings: [],
            errors: []
        )
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ label: String) throws {
        guard condition() else { throw SmokeError.expectationFailed(label) }
    }

    private enum SmokeError: Error {
        case expectationFailed(String)
    }
}
