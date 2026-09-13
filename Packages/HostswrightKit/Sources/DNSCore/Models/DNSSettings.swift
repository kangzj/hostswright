import Foundation

public struct ForwardingRule: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var domain: String
    public var servers: [String]

    public init(id: UUID = UUID(), domain: String, servers: [String]) {
        self.id = id
        self.domain = domain
        self.servers = servers
    }

    public var suffix: DNSName? {
        let trimmed = domain.trimmingCharacters(in: .whitespaces)
        return DNSName(trimmed.trimmingCharacters(in: CharacterSet(charactersIn: ".")))
    }

    public func matches(_ name: DNSName) -> Bool {
        guard let suffix else { return false }
        return name.hasSuffix(suffix)
    }
}

public enum UpstreamSource: Codable, Hashable, Sendable {
    case automatic
    case custom([String])
}

public struct DNSSettings: Codable, Hashable, Sendable {
    public var isEnabled: Bool
    public var upstream: UpstreamSource
    public var minimumTTL: UInt32
    public var maximumTTL: UInt32
    public var rules: [ForwardingRule]
    public var keepsQueryLog: Bool

    public static let `default` = DNSSettings()

    public init(
        isEnabled: Bool = false,
        upstream: UpstreamSource = .automatic,
        minimumTTL: UInt32 = 30,
        maximumTTL: UInt32 = 3600,
        rules: [ForwardingRule] = [],
        keepsQueryLog: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.upstream = upstream
        self.minimumTTL = minimumTTL
        self.maximumTTL = maximumTTL
        self.rules = rules
        self.keepsQueryLog = keepsQueryLog
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = DNSSettings.default
        self.init(
            isEnabled: try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? defaults.isEnabled,
            upstream: try container.decodeIfPresent(UpstreamSource.self, forKey: .upstream) ?? defaults.upstream,
            minimumTTL: try container.decodeIfPresent(UInt32.self, forKey: .minimumTTL) ?? defaults.minimumTTL,
            maximumTTL: try container.decodeIfPresent(UInt32.self, forKey: .maximumTTL) ?? defaults.maximumTTL,
            rules: try container.decodeIfPresent([ForwardingRule].self, forKey: .rules) ?? defaults.rules,
            keepsQueryLog: try container.decodeIfPresent(Bool.self, forKey: .keepsQueryLog) ?? defaults.keepsQueryLog
        )
    }
}
