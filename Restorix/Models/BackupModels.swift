import Foundation

enum BackupTool: String, Codable {
    case Restic
    case Borg
    case Rclone
    case Unknown

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: value) ?? .Unknown
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
struct BackupRepository: Codable, Identifiable {
    let id: String
    let name: String
    let tool: BackupTool
    let location: String
    let passwordEnvKey: String?
    let expectedHostname: String?
    let enabled: Bool
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case tool
        case location
        case passwordEnvKey = "password_env_key"
        case expectedHostname = "expected_hostname"
        case enabled
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
struct BackupSnapshot: Codable, Identifiable {
    let id: String
    let repositoryId: String
    let tool: BackupTool
    let time: String
    let paths: [String]
    let sizeBytes: UInt64?
    let hostname: String?
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case repositoryId = "repository_id"
        case tool
        case time
        case paths
        case sizeBytes = "size_bytes"
        case hostname
        case tags
    }
}
