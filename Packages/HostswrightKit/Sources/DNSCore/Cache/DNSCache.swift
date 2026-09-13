import Foundation

public struct DNSCache: Sendable {
    private struct Entry {
        var raw: Data
        var records: [DNSRecordSummary]
        var storedAt: Date
        var expiresAt: Date
    }

    public var minimumTTL: UInt32
    public var maximumTTL: UInt32
    public let capacity: Int
    public private(set) var hits = 0
    public private(set) var misses = 0

    private var entries: [DNSQuestion: Entry] = [:]

    public init(minimumTTL: UInt32, maximumTTL: UInt32, capacity: Int = 10_000) {
        self.minimumTTL = minimumTTL
        self.maximumTTL = maximumTTL
        self.capacity = capacity
    }

    public var count: Int { entries.count }

    public mutating func lookup(_ question: DNSQuestion, id: UInt16, now: Date) -> Data? {
        guard let entry = entries[question], now < entry.expiresAt else {
            entries[question] = nil
            misses += 1
            return nil
        }
        hits += 1
        let elapsed = UInt32(clamping: Int(now.timeIntervalSince(entry.storedAt).rounded(.down)))
        return DNSWire.adjusting(entry.raw, id: id, records: entry.records, elapsed: elapsed)
    }

    public mutating func store(_ message: DNSMessage, raw: Data, now: Date) {
        guard let question = message.question,
              message.header.responseCode == .noError || message.header.responseCode == .nameError
        else { return }
        let ttl = min(max(Self.cacheTTL(of: message) ?? minimumTTL, minimumTTL), maximumTTL)
        if entries[question] == nil { makeRoom(now: now) }
        entries[question] = Entry(
            raw: DNSWire.rewritingTTLs(in: raw, id: message.header.id, records: message.records) { min($0, maximumTTL) },
            records: message.records,
            storedAt: now,
            expiresAt: now.addingTimeInterval(TimeInterval(ttl))
        )
    }

    public mutating func removeAll() {
        entries.removeAll()
    }

    public static func cacheTTL(of message: DNSMessage) -> UInt32? {
        if let answerTTL = message.answers.map(\.ttl).min() { return answerTTL }
        if let soa = message.authorities.first(where: { $0.type == .soa }), soa.rdata.count >= 4 {
            let minimum = soa.rdata.suffix(4).reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
            return min(minimum, soa.ttl)
        }
        return message.authorities.map(\.ttl).min()
    }

    private mutating func makeRoom(now: Date) {
        guard entries.count >= capacity else { return }
        entries = entries.filter { now < $0.value.expiresAt }
        while entries.count >= capacity, let oldest = entries.min(by: { $0.value.storedAt < $1.value.storedAt }) {
            entries[oldest.key] = nil
        }
    }
}
