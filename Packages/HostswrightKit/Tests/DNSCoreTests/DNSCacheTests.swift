import Foundation
import Testing
@testable import DNSCore

@Suite struct DNSCacheTests {
    let start = Date(timeIntervalSince1970: 1_000_000)
    let question = DNSQuestion(name: DNSName("example.com")!, type: .a)

    func storedCache(minimumTTL: UInt32 = 0, maximumTTL: UInt32 = 3600, capacity: Int = 10) throws -> DNSCache {
        var cache = DNSCache(minimumTTL: minimumTTL, maximumTTL: maximumTTL, capacity: capacity)
        let raw = WireFixtures.exampleResponse(id: 0x1111, cnameTTL: 300, aTTL: 60)
        cache.store(try DNSMessage.parse(raw), raw: raw, now: start)
        return cache
    }

    @Test func missOnEmptyCache() {
        var cache = DNSCache(minimumTTL: 0, maximumTTL: 60)
        #expect(cache.lookup(question, id: 1, now: start) == nil)
        #expect(cache.misses == 1)
        #expect(cache.hits == 0)
        #expect(cache.count == 0)
    }

    @Test func hitReturnsAdjustedTTLsAndNewID() throws {
        var cache = try storedCache()
        #expect(cache.count == 1)
        let hit = cache.lookup(question, id: 0x2222, now: start.addingTimeInterval(10))
        let message = try DNSMessage.parse(try #require(hit))
        #expect(message.header.id == 0x2222)
        #expect(message.answers.map(\.ttl) == [290, 50])
        #expect(cache.hits == 1)
        #expect(cache.misses == 0)
    }

    @Test func expiresAfterMinimumAnswerTTL() throws {
        var cache = try storedCache()
        #expect(cache.lookup(question, id: 1, now: start.addingTimeInterval(59)) != nil)
        #expect(cache.lookup(question, id: 1, now: start.addingTimeInterval(60)) == nil)
        #expect(cache.count == 0)
        #expect(cache.hits == 1)
        #expect(cache.misses == 1)
    }

    @Test func clampsToMinimumTTL() throws {
        var cache = try storedCache(minimumTTL: 120)
        #expect(cache.lookup(question, id: 1, now: start.addingTimeInterval(119)) != nil)
        #expect(cache.lookup(question, id: 1, now: start.addingTimeInterval(120)) == nil)
    }

    @Test func clampsToMaximumTTLAndCapsServedTTLs() throws {
        var cache = try storedCache(maximumTTL: 30)
        let hit = cache.lookup(question, id: 1, now: start.addingTimeInterval(10))
        #expect(try DNSMessage.parse(try #require(hit)).answers.map(\.ttl) == [20, 20])
        #expect(cache.lookup(question, id: 1, now: start.addingTimeInterval(30)) == nil)
    }

    @Test func doesNotCacheServerFailures() throws {
        var cache = DNSCache(minimumTTL: 10, maximumTTL: 60)
        let raw = DNSAnswerBuilder.errorResponse(to: try DNSMessage.parse(WireFixtures.query()), code: .serverFailure)
        cache.store(try DNSMessage.parse(raw), raw: raw, now: start)
        #expect(cache.count == 0)
        let headerOnly = DNSAnswerBuilder.errorResponse(id: 1, code: .notImplemented)
        cache.store(try DNSMessage.parse(headerOnly), raw: headerOnly, now: start)
        #expect(cache.count == 0)
    }

    @Test func negativeCachingUsesSOAMinimum() throws {
        var cache = DNSCache(minimumTTL: 0, maximumTTL: 3600)
        let raw = WireFixtures.nxdomainResponse(soaTTL: 900, soaMinimum: 120)
        let message = try DNSMessage.parse(raw)
        #expect(DNSCache.cacheTTL(of: message) == 120)
        cache.store(message, raw: raw, now: start)
        let missing = DNSQuestion(name: DNSName("missing.example.com")!, type: .a)
        let hit = cache.lookup(missing, id: 5, now: start.addingTimeInterval(100))
        let served = try DNSMessage.parse(try #require(hit))
        #expect(served.header.responseCode == .nameError)
        #expect(served.authorities[0].ttl == 800)
        #expect(cache.lookup(missing, id: 5, now: start.addingTimeInterval(120)) == nil)
    }

    @Test func negativeCachingIsBoundedBySOARecordTTL() throws {
        let message = try DNSMessage.parse(WireFixtures.nxdomainResponse(soaTTL: 30, soaMinimum: 120))
        #expect(DNSCache.cacheTTL(of: message) == 30)
    }

    @Test func cacheTTLFallsBackToAuthorityTTLsThenNil() throws {
        let query = try DNSMessage.parse(WireFixtures.query())
        #expect(DNSCache.cacheTTL(of: query) == nil)
        let ns = DNSRecordSummary(name: DNSName("example.com")!, type: .ns, ttl: 77, ttlOffset: 0, rdata: Data())
        #expect(DNSCache.cacheTTL(of: DNSMessage(header: query.header, questions: query.questions, authorities: [ns])) == 77)
    }

    @Test func emptyResponseUsesMinimumTTL() throws {
        var cache = DNSCache(minimumTTL: 15, maximumTTL: 60)
        let query = try DNSMessage.parse(WireFixtures.query())
        let raw = DNSAnswerBuilder.hostsResponse(to: query, ipv4: [], ipv6: [], ttl: 1)
        cache.store(try DNSMessage.parse(raw), raw: raw, now: start)
        #expect(cache.lookup(question, id: 1, now: start.addingTimeInterval(14)) != nil)
        #expect(cache.lookup(question, id: 1, now: start.addingTimeInterval(15)) == nil)
    }

    @Test func evictsExpiredThenOldestWhenFull() throws {
        var cache = DNSCache(minimumTTL: 0, maximumTTL: 3600, capacity: 2)
        func store(_ host: String, at offset: TimeInterval) throws {
            let query = try DNSMessage.parse(WireFixtures.query(name: host))
            let raw = DNSAnswerBuilder.hostsResponse(to: query, ipv4: [IPv4Bytes("1.1.1.1")!], ipv6: [], ttl: 100)
            cache.store(try DNSMessage.parse(raw), raw: raw, now: start.addingTimeInterval(offset))
        }
        try store("a.test", at: 0)
        try store("b.test", at: 1)
        try store("c.test", at: 2)
        #expect(cache.count == 2)
        #expect(cache.lookup(DNSQuestion(name: DNSName("a.test")!, type: .a), id: 1, now: start.addingTimeInterval(3)) == nil)
        #expect(cache.lookup(DNSQuestion(name: DNSName("b.test")!, type: .a), id: 1, now: start.addingTimeInterval(3)) != nil)

        try store("d.test", at: 200)
        #expect(cache.count == 1)
        #expect(cache.lookup(DNSQuestion(name: DNSName("d.test")!, type: .a), id: 1, now: start.addingTimeInterval(201)) != nil)
    }

    @Test func restoringSameQuestionDoesNotEvict() throws {
        var cache = try storedCache(capacity: 1)
        let raw = WireFixtures.exampleResponse(cnameTTL: 500, aTTL: 500)
        cache.store(try DNSMessage.parse(raw), raw: raw, now: start.addingTimeInterval(1))
        #expect(cache.count == 1)
        #expect(cache.lookup(question, id: 1, now: start.addingTimeInterval(400)) != nil)
    }

    @Test func removeAllClearsEntriesButKeepsCounters() throws {
        var cache = try storedCache()
        _ = cache.lookup(question, id: 1, now: start)
        cache.removeAll()
        #expect(cache.count == 0)
        #expect(cache.hits == 1)
        #expect(cache.lookup(question, id: 1, now: start) == nil)
        #expect(cache.misses == 1)
    }

    @Test func changingBoundsDoesNotEvict() throws {
        var cache = try storedCache()
        cache.minimumTTL = 5
        cache.maximumTTL = 10
        #expect(cache.count == 1)
        #expect(cache.lookup(question, id: 1, now: start.addingTimeInterval(59)) != nil)
    }
}
