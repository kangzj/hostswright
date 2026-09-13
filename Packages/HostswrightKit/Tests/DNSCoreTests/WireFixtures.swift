import Foundation
@testable import DNSCore

enum WireFixtures {
    static func name(_ text: String) -> [UInt8] {
        text.split(separator: ".").flatMap { [UInt8($0.utf8.count)] + Array($0.utf8) } + [0]
    }

    static func u16(_ value: UInt16) -> [UInt8] { [UInt8(value >> 8), UInt8(value & 0xFF)] }

    static func u32(_ value: UInt32) -> [UInt8] {
        [UInt8(value >> 24), UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
    }

    static func header(id: UInt16, flags: UInt16, qd: UInt16 = 1, an: UInt16 = 0, ns: UInt16 = 0, ar: UInt16 = 0) -> [UInt8] {
        u16(id) + u16(flags) + u16(qd) + u16(an) + u16(ns) + u16(ar)
    }

    static func record(nameBytes: [UInt8], type: DNSRecordType, ttl: UInt32, rdata: [UInt8]) -> [UInt8] {
        nameBytes + u16(type.rawValue) + u16(1) + u32(ttl) + u16(UInt16(rdata.count)) + rdata
    }

    static let questionOffset = 12
    static let pointerToQuestionName: [UInt8] = [0xC0, 0x0C]

    static func query(id: UInt16 = 0x1234, name text: String = "example.com", type: DNSRecordType = .a, recursionDesired: Bool = true) -> Data {
        Data(header(id: id, flags: recursionDesired ? 0x0100 : 0) + name(text) + u16(type.rawValue) + u16(1))
    }

    /// Response for `example.com A` with a CNAME whose owner and target use compression pointers, followed by the A record.
    static func exampleResponse(id: UInt16 = 0x1234, cnameTTL: UInt32 = 300, aTTL: UInt32 = 60) -> Data {
        let question = name("example.com") + u16(DNSRecordType.a.rawValue) + u16(1)
        let cnameTarget = [UInt8(3)] + Array("www".utf8) + pointerToQuestionName
        let cname = record(nameBytes: pointerToQuestionName, type: .cname, ttl: cnameTTL, rdata: cnameTarget)
        let cnameRdataOffset = questionOffset + question.count + 2 + 2 + 2 + 4 + 2
        let a = record(nameBytes: [0xC0, UInt8(cnameRdataOffset)], type: .a, ttl: aTTL, rdata: [93, 184, 216, 34])
        return Data(header(id: id, flags: 0x8180, an: 2) + question + cname + a)
    }

    static func nxdomainResponse(id: UInt16 = 0x1234, soaTTL: UInt32 = 900, soaMinimum: UInt32 = 120) -> Data {
        let question = name("missing.example.com") + u16(DNSRecordType.a.rawValue) + u16(1)
        let soaRdata = name("ns1.example.com") + name("hostmaster.example.com") + u32(1) + u32(7200) + u32(3600) + u32(1_209_600) + u32(soaMinimum)
        let soa = record(nameBytes: name("example.com"), type: .soa, ttl: soaTTL, rdata: soaRdata)
        return Data(header(id: id, flags: 0x8183, ns: 1) + question + soa)
    }

    static func parsed(_ data: Data) throws -> DNSMessage {
        try DNSMessage.parse(data)
    }
}
