import Foundation

struct DNSWireReader {
    struct SectionCounts {
        var questions: Int
        var answers: Int
        var authorities: Int
        var additionals: Int
    }

    let bytes: [UInt8]
    private(set) var position = 0

    init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    mutating func readHeader() throws(DNSParseError) -> DNSHeader {
        let id = try readUInt16()
        let flags = try readUInt16()
        return DNSHeader(
            id: id,
            isResponse: flags & 0x8000 != 0,
            opcode: UInt8((flags >> 11) & 0x0F),
            isAuthoritative: flags & 0x0400 != 0,
            isTruncated: flags & 0x0200 != 0,
            recursionDesired: flags & 0x0100 != 0,
            recursionAvailable: flags & 0x0080 != 0,
            responseCode: DNSResponseCode(rawValue: UInt8(flags & 0x000F))
        )
    }

    mutating func readSectionCounts() throws(DNSParseError) -> SectionCounts {
        SectionCounts(
            questions: Int(try readUInt16()),
            answers: Int(try readUInt16()),
            authorities: Int(try readUInt16()),
            additionals: Int(try readUInt16())
        )
    }

    mutating func readQuestion() throws(DNSParseError) -> DNSQuestion {
        let name = try readName()
        let type = DNSRecordType(rawValue: try readUInt16())
        let klass = try readUInt16()
        return DNSQuestion(name: name, type: type, klass: klass)
    }

    mutating func readRecord() throws(DNSParseError) -> DNSRecordSummary {
        let name = try readName()
        let type = DNSRecordType(rawValue: try readUInt16())
        let klass = try readUInt16()
        let ttlOffset = position
        let ttl = try readUInt32()
        let length = Int(try readUInt16())
        let rdata = try readBytes(length)
        return DNSRecordSummary(name: name, type: type, klass: klass, ttl: ttl, ttlOffset: ttlOffset, rdata: rdata)
    }

    // Pointers must point strictly backwards, which rules out loops and forward references in one check.
    mutating func readName() throws(DNSParseError) -> DNSName {
        var labels: [String] = []
        var cursor = position
        var resumeAt: Int?
        while true {
            guard cursor < bytes.count else { throw DNSParseError.truncated }
            let length = Int(bytes[cursor])
            if length & 0xC0 == 0xC0 {
                guard cursor + 1 < bytes.count else { throw DNSParseError.truncated }
                let target = ((length & 0x3F) << 8) | Int(bytes[cursor + 1])
                guard target < cursor else { throw DNSParseError.invalidPointer }
                if resumeAt == nil { resumeAt = cursor + 2 }
                cursor = target
                continue
            }
            guard length <= DNSName.maximumLabelLength else { throw DNSParseError.labelTooLong }
            cursor += 1
            if length == 0 { break }
            guard cursor + length <= bytes.count else { throw DNSParseError.truncated }
            guard labels.count < DNSName.maximumLabelCount else { throw DNSParseError.tooManyLabels }
            labels.append(String(decoding: bytes[cursor..<(cursor + length)], as: UTF8.self))
            cursor += length
        }
        position = resumeAt ?? cursor
        return DNSName(labels: labels)
    }

    mutating func readUInt16() throws(DNSParseError) -> UInt16 {
        let slice = try readBytes(2)
        return UInt16(slice[0]) << 8 | UInt16(slice[1])
    }

    mutating func readUInt32() throws(DNSParseError) -> UInt32 {
        let slice = try readBytes(4)
        return UInt32(slice[0]) << 24 | UInt32(slice[1]) << 16 | UInt32(slice[2]) << 8 | UInt32(slice[3])
    }

    mutating func readBytes(_ count: Int) throws(DNSParseError) -> Data {
        guard position + count <= bytes.count else { throw DNSParseError.truncated }
        defer { position += count }
        return Data(bytes[position..<(position + count)])
    }
}
