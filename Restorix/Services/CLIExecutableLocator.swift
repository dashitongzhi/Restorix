import Foundation

struct CLIExecutableLocator {
    private let overrideURL: URL?

    init(overrideURL: URL? = nil) {
        self.overrideURL = overrideURL
    }

    func resolve() -> URL {
        if let overrideURL {
            return overrideURL
        }

        return Self.defaultCLIURL()
    }

    private static func defaultCLIURL() -> URL {
        if let configured = configuredCLIURL() {
            if shouldStageAppBundleResource(configured),
               let staged = stageBundledCLI(from: configured) {
                return staged
            }
            return configured
        }

        if let bundled = Bundle.main.url(forResource: "restorix", withExtension: nil),
           let staged = stageBundledCLI(from: bundled) {
            return staged
        }

        let candidates = [
            "/usr/local/bin/restorix",
            "/opt/homebrew/bin/restorix",
            FileManager.default.currentDirectoryPath + "/target/debug/restorix"
        ]

        if let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return URL(fileURLWithPath: path)
        }

        return URL(fileURLWithPath: "/usr/local/bin/restorix")
    }

    private static func configuredCLIURL() -> URL? {
        guard let configURL = configURL(),
              let data = try? Data(contentsOf: configURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let path = object["cli_path"] as? String else {
            return nil
        }

        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, FileManager.default.isExecutableFile(atPath: trimmed) else {
            return nil
        }

        return URL(fileURLWithPath: trimmed)
    }

    private static func shouldStageAppBundleResource(_ url: URL) -> Bool {
        let components = url.standardizedFileURL.pathComponents
        guard url.lastPathComponent == "restorix",
              let contentsIndex = components.lastIndex(of: "Contents"),
              contentsIndex + 1 < components.count else {
            return false
        }

        return components[contentsIndex + 1] == "Resources"
    }

    private static func configURL() -> URL? {
        if let override = ProcessInfo.processInfo.environment["RESTORIX_CONFIG"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }

        return applicationSupportDirectoryURL()?.appendingPathComponent("config.json")
    }

    private static func stageBundledCLI(from bundledURL: URL) -> URL? {
        let fileManager = FileManager.default
        guard let binDirectory = applicationSupportDirectoryURL()?.appendingPathComponent("bin", isDirectory: true) else {
            return nil
        }

        let stagedURL = binDirectory.appendingPathComponent("restorix")

        do {
            try fileManager.createDirectory(at: binDirectory, withIntermediateDirectories: true)
            if shouldStageBundledCLI(from: bundledURL, to: stagedURL) {
                if fileManager.fileExists(atPath: stagedURL.path) {
                    try fileManager.removeItem(at: stagedURL)
                }
                try fileManager.copyItem(at: bundledURL, to: stagedURL)
                try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: stagedURL.path)
            }
            return fileManager.isExecutableFile(atPath: stagedURL.path) ? stagedURL : nil
        } catch {
            return nil
        }
    }

    private static func shouldStageBundledCLI(from bundledURL: URL, to stagedURL: URL) -> Bool {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: stagedURL.path) else {
            return true
        }

        let bundledAttributes = try? fileManager.attributesOfItem(atPath: bundledURL.path)
        let stagedAttributes = try? fileManager.attributesOfItem(atPath: stagedURL.path)
        let bundledSize = bundledAttributes?[.size] as? UInt64
        let stagedSize = stagedAttributes?[.size] as? UInt64
        if bundledSize != stagedSize {
            return true
        }

        guard let bundledModified = bundledAttributes?[.modificationDate] as? Date,
              let stagedModified = stagedAttributes?[.modificationDate] as? Date else {
            return !filesMatch(bundledURL, stagedURL)
        }

        return bundledModified > stagedModified || !filesMatch(bundledURL, stagedURL)
    }

    private static func filesMatch(_ leftURL: URL, _ rightURL: URL) -> Bool {
        guard let leftData = try? Data(contentsOf: leftURL),
              let rightData = try? Data(contentsOf: rightURL) else {
            return false
        }

        return leftData == rightData
    }

    private static func applicationSupportDirectoryURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Restorix", isDirectory: true)
    }
}
