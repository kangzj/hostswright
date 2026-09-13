import Foundation
import Testing
@testable import DNSCore

@Suite struct DNSMessageTests {
    @Test func parsesQuery() throws {
        let message = try DNSMessage.parse(WireFixtures.query(id: 0xBEEF, name: "Example.com", type: .aaaa))
        #expect(message.header.id == 0xBEEF)
        #expect(!message.header.isResponse)
        #expect(message.header.recursionDesired)
        #expect(message.header.opcode == 0)
        #expect(message.question == DNSQuestion(name: DNSName("example.com")!, type: .aaaa))
        #expect(message.answers.isEmpty)
    }

    @Test func parsesResponseWithCompressionPointers() throws {
        let data = WireFixtures.exampleResponse(id: 0x1234, cnameTTL: 300, aTTL: 60)
        let message = try DNSMessage.parse(data)
        #expect(message.header.isResponse)
        #expect(message.header.recursionDesired)
        #expect(message.header.recursionAvailable)
        #expect(!message.header.isAuthoritative)
        #expect(message.header.responseCode == .noError)
        #expect(message.questions.count == 1)
        #expect(message.answers.count == 2)

        let cname = message.answers[0]
        #expect(cname.name == DNSName("example.com"))
        #expect(cname.type == .cname)
        #expect(cname.ttl == 300)
        #expect(cname.rdata == Data([3] + Array("www".utf8) + [0xC0, 0x0C]))

        let a = message.answers[1]
        #expect(a.name == DNSName("www.example.com"))
        #expect(a.type == .a)
        #expect(a.ttl == 60)
        #expect(a.rdata == Data([93, 184, 216, 34]))

        let bytes = [UInt8](data)
        #expect(Array(bytes[cname.ttlOffset..<(cname.ttlOffset + 4)]) == WireFixtures.u32(300))
        #expect(Array(bytes[a.ttlOffset..<(a.ttlOffset + 4)]) == WireFixtures.u32(60))
    }

    @Test func parsesAuthoritySection() throws {
        let message = try DNSMessage.parse(WireFixtures.nxdomainResponse())
        #expect(message.header.responseCode == .nameError)
        #expect(message.answers.isEmpty)
        #expect(message.authorities.count == 1)
        #expect(message.authorities[0].type == .soa)
        #expect(message.authorities[0].name == DNSName("example.com"))
    }

    @Test func rejectsTruncatedData() {
        let data = WireFixtures.exampleResponse()
        #expect(throws: DNSParseError.truncated) { try DNSMessage.parse(data.prefix(5)) }
        #expect(throws: DNSParseError.truncated) { try DNSMessage.parse(data.prefix(20)) }
        #expect(throws: DNSParseError.truncated) { try DNSMessage.parse(data.dropLast(1)) }
    }

    @Test func rejectsPointerLoopsAndForwardPointers() {
        let selfPointer = Data(WireFixtures.header(id: 1, flags: 0) + [0xC0, 0x0C] + WireFixtures.u16(1) + WireFixtures.u16(1))
        #expect(throws: DNSParseError.invalidPointer) { try DNSMessage.parse(selfPointer) }

        let forward = Data(WireFixtures.header(id: 1, flags: 0) + [0xC0, 0x10] + WireFixtures.u16(1) + WireFixtures.u16(1) + [0xC0, 0x0C])
        #expect(throws: DNSParseError.invalidPointer) { try DNSMessage.parse(forward) }
    }

    @Test func rejectsOverlongLabels() {
        let data = Data(WireFixtures.header(id: 1, flags: 0) + [64] + [UInt8](repeating: 0x61, count: 64) + [0] + WireFixtures.u16(1) + WireFixtures.u16(1))
        #expect(throws: DNSParseError.labelTooLong) { try DNSMessage.parse(data) }
    }

    @Test func rejectsTooManyLabels() {
        let labels = [UInt8](repeating: 0, count: 0) + (0..<128).flatMap { _ in [UInt8(1), 0x61] }
        let data = Data(WireFixtures.header(id: 1, flags: 0) + labels + [0] + WireFixtures.u16(1) + WireFixtures.u16(1))
        #expect(throws: DNSParseError.tooManyLabels) { try DNSMessage.parse(data) }
    }

    @Test func parsesOffsetDataSlice() throws {
        let padded = Data([0xFF, 0xFF]) + WireFixtures.exampleResponse()
        let message = try DNSMessage.parse(padded.dropFirst(2))
        #expect(message.answers.count == 2)
        #expect(message.answers[0].ttlOffset == WireFixtures.questionOffset + 17 + 2 + 2 + 2)
    }

    @Test func recordTypeDescriptions() {
        #expect(DNSRecordType.a.description == "A")
        #expect(DNSRecordType.aaaa.description == "AAAA")
        #expect(DNSRecordType.https.description == "HTTPS")
        #expect(DNSRecordType(rawValue: 123).description == "TYPE123")
        #expect(DNSRecordType.any.rawValue == 255)
        #expect(DNSRecordType.opt.rawValue == 41)
    }
}
