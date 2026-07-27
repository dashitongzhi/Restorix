import Foundation

enum Platform: String, Codable {
    case MacOS
    case Windows
    case Linux
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
struct DockerContainer: Codable, Identifiable {
    var id: String
    let name: String
    let image: String
    let status: String
    let running: Bool
    let volumes: [DockerVolumeMount]
}
struct DockerVolumeMount: Codable {
    let volumeName: String?
    let source: String
    let destination: String
    let mode: String?

    enum CodingKeys: String, CodingKey {
        case volumeName = "volume_name"
        case source
        case destination
        case mode
    }
}

struct DockerVolume: Codable, Identifiable {
    var id: String { name }
    let name: String
    let driver: String
    let mountpoint: String
    let labels: [[String]]
}
