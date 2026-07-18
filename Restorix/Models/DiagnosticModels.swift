import Foundation

enum DiagnosticCode: String, Codable, Hashable {
    case configLoadFailed = "config_load_failed"
    case dockerUnavailable = "docker_unavailable"
    case resticUnavailable = "restic_unavailable"
    case resticCheckFailed = "restic_check_failed"
    case dockerContainerScanFailed = "docker_container_scan_failed"
    case dockerVolumeScanFailed = "docker_volume_scan_failed"
    case dockerVolumeInspectFailed = "docker_volume_inspect_failed"
    case repositoryScanFailed = "repository_scan_failed"
    case resticRequiredMissing = "restic_required_missing"
    case backupVerificationUnconfigured = "backup_verification_unconfigured"
    case statefulVolumes = "stateful_volumes"
    case volumeMountpointMissing = "volume_mountpoint_missing"
    case noEnabledRepositories = "no_enabled_repositories"
    case noSnapshotMatch = "no_snapshot_match"
    case missingExpectedHostname = "missing_expected_hostname"
    case childPathOnly = "child_path_only"
    case volumeNameMatchOnly = "volume_name_match_only"
    case unreliableSnapshotMatch = "unreliable_snapshot_match"
    case futureSnapshot = "future_snapshot"
    case staleSnapshot = "stale_snapshot"
    case recentSnapshot = "recent_snapshot"
    case snapshotTimeUnparseable = "snapshot_time_unparseable"
    case repositoryCoverageUnknown = "repository_coverage_unknown"
    case looseMatchingDisabled = "loose_matching_disabled"
    case generic

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: value) ?? .generic
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct DiagnosticContext: Codable, Hashable {
    let hours: Int?
    let volumes: [String]?
    let repository: String?
    let detail: String?

    init(hours: Int? = nil, volumes: [String]? = nil, repository: String? = nil, detail: String? = nil) {
        self.hours = hours
        self.volumes = volumes
        self.repository = repository
        self.detail = detail
    }
}

struct Diagnostic: Codable, Hashable, Identifiable {
    let code: DiagnosticCode
    let context: DiagnosticContext
    let message: String

    private enum CodingKeys: String, CodingKey {
        case code
        case context
        case message
    }

    init(code: DiagnosticCode, context: DiagnosticContext, message: String) {
        self.code = code
        self.context = context
        self.message = message
    }

    init(from decoder: Decoder) throws {
        if let legacyMessage = try? decoder.singleValueContainer().decode(String.self) {
            code = .generic
            context = DiagnosticContext()
            message = legacyMessage
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(DiagnosticCode.self, forKey: .code)
        context = try container.decodeIfPresent(DiagnosticContext.self, forKey: .context) ?? DiagnosticContext()
        message = try container.decode(String.self, forKey: .message)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .code)
        try container.encode(context, forKey: .context)
        try container.encode(message, forKey: .message)
    }

    var id: String {
        "\(code.rawValue)|\(message)"
    }

    func localizedMessage(language: AppLanguage) -> String {
        guard language == .simplifiedChinese else { return message }

        switch code {
        case .volumeMountpointMissing:
            return "Docker 元数据不完整：volume 挂载路径为空。"
        case .noEnabledRepositories:
            return "还没有配置已启用的备份仓库。"
        case .noSnapshotMatch:
            return "没有可靠的 snapshot 路径匹配这个 Docker volume 挂载点。"
        case .volumeNameMatchOnly:
            return "只找到了 volume 名称匹配。启用宽松匹配后才会把它视为已保护。"
        case .recentSnapshot:
            return "最近的 restic snapshot 匹配这个 Docker volume 挂载点。"
        case .snapshotTimeUnparseable:
            return "找到了匹配的 snapshot，但无法解析它的时间戳。"
        case .futureSnapshot:
            return "匹配的 snapshot 时间戳在未来，因此无法判断备份是否新鲜。"
        case .repositoryCoverageUnknown:
            return "至少一个仓库扫描失败，因此 Restorix 无法确认这个 volume 未受保护。"
        case .missingExpectedHostname:
            return "已启用仓库未配置预期快照主机名，因此 Restorix 无法证明此主机的备份覆盖。"
        case .resticRequiredMissing:
            return "至少一个已启用仓库需要 restic，但当前没有安装 restic。"
        case .resticUnavailable:
            return "未安装 restic。可以使用 Homebrew 安装：brew install restic"
        case .resticCheckFailed:
            if let detail = context.detail {
                return "restic 可执行文件检查失败：\(detail)"
            }
            return message
        case .backupVerificationUnconfigured:
            return "还没有配置已启用的备份仓库，因此 Restorix 可以列出 Docker volumes，但无法验证备份。"
        case .staleSnapshot:
            return "最新匹配的 snapshot 已超过过期阈值（\(context.hours ?? 0) 小时）。"
        case .statefulVolumes:
            return "这些 volumes 看起来是有状态服务或数据库数据：\((context.volumes ?? []).joined(separator: ", "))。文件级 snapshots 可能仍需要应用级 dump，或在容器停止后创建，才能保证恢复一致性。"
        case .childPathOnly:
            return "snapshot 只覆盖了这个 Docker volume 内的子路径，因此无法确认整个 volume 已受保护。"
        case .unreliableSnapshotMatch:
            return "snapshot 覆盖关系不够可靠，无法判断整个 volume 的保护状态。"
        case .repositoryScanFailed:
            if let repository = context.repository, let detail = context.detail {
                return "仓库 \(repository) 扫描失败：\(detail)"
            }
            return message
        case .looseMatchingDisabled:
            return "宽松匹配已关闭。"
        default:
            return message
        }
    }
}
