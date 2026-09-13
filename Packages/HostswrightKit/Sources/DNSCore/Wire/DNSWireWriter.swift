import Foundation

struct DNSWireWriter {
    private(set) var bytes: [UInt8] = []

    var data: Data { Data(bytes) }

    mutating func append(_ value: UInt8) {
        bytes.append(value)
    }

    mutating func append(_ value: UInt16) {
        bytes.append(UInt8(value >> 8))
        bytes.append(UInt8(value & 0xFF))
    }

    mutating func append(_ value: UInt32) {
        append(UInt16(value >> 16))
        append(UInt16(value & 0xFFFF))
    }

    mutating func append(_ data: some Sequence<UInt8>) {
        bytes.append(contentsOf: data)
    }

    mutating func append(_ name: DNSName) {
        for label in name.labels {
            append(UInt8(label.utf8.count))
            append(label.utf8)
        }
        append(UInt8(0))
    }

    mutating func append(_ question: DNSQuestion) {
        append(question.name)
        append(question.type.rawValue)
        append(question.klass)
    }

    mutating func append(_ header: DNSHeader, questions: Int, answers: Int, authorities: Int = 0, additionals: Int = 0) {
        append(header.id)
        append(header.flags)
        append(UInt16(questions))
        append(UInt16(answers))
        append(UInt16(authorities))
        append(UInt16(additionals))
    }
}

extension DNSHeader {
    var flags: UInt16 {
        var flags: UInt16 = UInt16(opcode & 0x0F) << 11 | UInt16(responseCode.rawValue & 0x0F)
        if isResponse { flags |= 0x8000 }
        if isAuthoritative { flags |= 0x0400 }
        if isTruncated { flags |= 0x0200 }
        if recursionDesired { flags |= 0x0100 }
        if recursionAvailable { flags |= 0x0080 }
        return flags
    }
}
