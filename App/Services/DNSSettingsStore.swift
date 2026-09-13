import DNSCore
import Foundation

final class DNSSettingsStore: Sendable {
    private let fileURL: URL

    init(directory: URL) {
        fileURL = directory.appendingPathComponent("dns.json")
    }

    func load() -> DNSSettings {
        guard let data = try? Data(contentsOf: fileURL),
              let settings = try? JSONDecoder().decode(DNSSettings.self, from: data)
        else { return .default }
        return settings
    }

    func save(_ settings: DNSSettings) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings).write(to: fileURL, options: .atomic)
    }
}
