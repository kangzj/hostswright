import Foundation
import Testing
@testable import DNSCore

@Suite struct DNSWireTests {
    @Test func readsHeaderAndID() throws {
        let data = WireFixtures.exampleResponse(id: 0xABCD)
        #expect(DNSWire.id(of: data) == 0xABCD)
        let header = try #require(DNSWire.header(of: data))
        #expect(header.id == 0xABCD)
        #expect(header.isResponse)
        #expect(header.recursionAvailable)
        #expect(DNSWire.header(of: Data([1, 2, 3])) == nil)
        #expect(DNSWire.id(of: Data([1])) == nil)
    }

    @Test func replacesID() throws {
        let data = DNSWire.settingID(0x0102, in: WireFixtures.exampleResponse(id: 0xFFFF))
        #expect(DNSWire.id(of: data) == 0x0102)
        #expect(try DNSMessage.parse(data).answers.count == 2)
    }

    @Test func adjustsTTLsAndID() throws {
        let original = WireFixtures.exampleResponse(id: 1, cnameTTL: 300, aTTL: 60)
        let records = try DNSMessage.parse(original).answers
        let adjusted = DNSWire.adjusting(original, id: 0x4242, records: records, elapsed: 45)
        let message = try DNSMessage.parse(adjusted)
        #expect(message.header.id == 0x4242)
        #expect(message.answers.map(\.ttl) == [255, 15])
        #expect(adjusted.count == original.count)
        #expect(DNSWire.id(of: original) == 1)
    }

    @Test func floorsTTLsAtZero() throws {
        let original = WireFixtures.exampleResponse(cnameTTL: 300, aTTL: 60)
        let records = try DNSMessage.parse(original).answers
        let adjusted = DNSWire.adjusting(original, id: 7, records: records, elapsed: 100)
        #expect(try DNSMessage.parse(adjusted).answers.map(\.ttl) == [200, 0])
    }

    @Test func ignoresOutOfRangeOffsets() {
        let original = WireFixtures.query()
        let bogus = DNSRecordSummary(name: DNSName("x")!, type: .a, ttl: 1, ttlOffset: original.count - 2, rdata: Data())
        #expect(DNSWire.adjusting(original, id: 3, records: [bogus], elapsed: 1).dropFirst(2) == original.dropFirst(2))
    }
}
