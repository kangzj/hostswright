import Foundation

public final class ConfigurationStore: Sendable {
    // HOSTSWRIGHT_CONFIG_DIR lets a development copy run against a separate configuration, e.g. for screenshots.
    public static var defaultDirectory: URL {
        if let override = ProcessInfo.processInfo.environment["HOSTSWRIGHT_CONFIG_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Hostswright", isDirectory: true)
    }

    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public var exists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    public func load() -> AppConfiguration {
        guard let data = try? Data(contentsOf: fileURL),
              let configuration = try? JSONDecoder().decode(AppConfiguration.self, from: data)
        else { return .default }
        return configuration
    }

    public func save(_ configuration: AppConfiguration) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(configuration).write(to: fileURL, options: .atomic)
    }

    private var fileURL: URL {
        directory.appendingPathComponent("configuration.json")
    }
}
