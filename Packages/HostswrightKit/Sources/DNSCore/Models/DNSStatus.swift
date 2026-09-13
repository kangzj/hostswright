import Foundation

public enum QueryOutcome: Codable, Hashable, Sendable {
    case hosts
    case cache
    case forwarded(server: String)
    case rule(server: String)
    case failed(reason: String)
}

public struct QueryLogEntry: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var time: Date
    public var name: String
    public var type: String
    public var outcome: QueryOutcome
    public var durationMilliseconds: Int

    public init(id: UUID = UUID(), time: Date, name: String, type: String, outcome: QueryOutcome, durationMilliseconds: Int) {
        self.id = id
        self.time = time
        self.name = name
        self.type = type
        self.outcome = outcome
        self.durationMilliseconds = durationMilliseconds
    }
}

public struct DNSStatus: Codable, Hashable, Sendable {
    public var isRunning: Bool
    public var listenError: String?
    public var upstreams: [String]
    public var cacheEntries: Int
    public var hits: Int
    public var misses: Int
    public var queries: Int
    public var log: [QueryLogEntry]

    public static let stopped = DNSStatus()

    public init(
        isRunning: Bool = false,
        listenError: String? = nil,
        upstreams: [String] = [],
        cacheEntries: Int = 0,
        hits: Int = 0,
        misses: Int = 0,
        queries: Int = 0,
        log: [QueryLogEntry] = []
    ) {
        self.isRunning = isRunning
        self.listenError = listenError
        self.upstreams = upstreams
        self.cacheEntries = cacheEntries
        self.hits = hits
        self.misses = misses
        self.queries = queries
        self.log = log
    }

    public var hitRate: Double? {
        let total = hits + misses
        return total == 0 ? nil : Double(hits) / Double(total)
    }
}
