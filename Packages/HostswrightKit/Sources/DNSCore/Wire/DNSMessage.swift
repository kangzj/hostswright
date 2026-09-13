import Foundation

public struct DNSQuestion: Hashable, Sendable {
    public var name: DNSName
    public var type: DNSRecordType
    public var klass: UInt16

    public init(name: DNSName, type: DNSRecordType, klass: UInt16 = 1) {
        self.name = name
        self.type = type
        self.klass = klass
    }
}

public struct DNSResponseCode: RawRepresentable, Hashable, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let noError = DNSResponseCode(rawValue: 0)
    public static let formatError = DNSResponseCode(rawValue: 1)
    public static let serverFailure = DNSResponseCode(rawValue: 2)
    public static let nameError = DNSResponseCode(rawValue: 3)
    public static let notImplemented = DNSResponseCode(rawValue: 4)
    public static let refused = DNSResponseCode(rawValue: 5)
}

public struct DNSHeader: Hashable, Sendable {
    public static let byteCount = 12

    public var id: UInt16
    public var isResponse: Bool
    public var opcode: UInt8
    public var isAuthoritative: Bool
    public var isTruncated: Bool
    public var recursionDesired: Bool
    public var recursionAvailable: Bool
    public var responseCode: DNSResponseCode

    public init(
        id: UInt16,
        isResponse: Bool,
        opcode: UInt8 = 0,
        isAuthoritative: Bool = false,
        isTruncated: Bool = false,
        recursionDesired: Bool = false,
        recursionAvailable: Bool = false,
        responseCode: DNSResponseCode = .noError
    ) {
        self.id = id
        self.isResponse = isResponse
        self.opcode = opcode
        self.isAuthoritative = isAuthoritative
        self.isTruncated = isTruncated
        self.recursionDesired = recursionDesired
        self.recursionAvailable = recursionAvailable
        self.responseCode = responseCode
    }
}

public struct DNSRecordSummary: Hashable, Sendable {
    public var name: DNSName
    public var type: DNSRecordType
    public var klass: UInt16
    public var ttl: UInt32
    public var ttlOffset: Int
    public var rdata: Data

    public init(name: DNSName, type: DNSRecordType, klass: UInt16 = 1, ttl: UInt32, ttlOffset: Int, rdata: Data) {
        self.name = name
        self.type = type
        self.klass = klass
        self.ttl = ttl
        self.ttlOffset = ttlOffset
        self.rdata = rdata
    }
}

public enum DNSParseError: Error, Equatable {
    case truncated
    case invalidPointer
    case labelTooLong
    case tooManyLabels
}

public struct DNSMessage: Sendable {
    public var header: DNSHeader
    public var questions: [DNSQuestion]
    public var answers: [DNSRecordSummary]
    public var authorities: [DNSRecordSummary]
    public var additionals: [DNSRecordSummary]

    public init(
        header: DNSHeader,
        questions: [DNSQuestion] = [],
        answers: [DNSRecordSummary] = [],
        authorities: [DNSRecordSummary] = [],
        additionals: [DNSRecordSummary] = []
    ) {
        self.header = header
        self.questions = questions
        self.answers = answers
        self.authorities = authorities
        self.additionals = additionals
    }

    public var question: DNSQuestion? { questions.first }

    public var records: [DNSRecordSummary] { answers + authorities + additionals }

    public static func parse(_ data: Data) throws(DNSParseError) -> DNSMessage {
        var reader = DNSWireReader(bytes: [UInt8](data))
        let header = try reader.readHeader()
        let counts = try reader.readSectionCounts()
        var message = DNSMessage(header: header)
        for _ in 0..<counts.questions { message.questions.append(try reader.readQuestion()) }
        for _ in 0..<counts.answers { message.answers.append(try reader.readRecord()) }
        for _ in 0..<counts.authorities { message.authorities.append(try reader.readRecord()) }
        for _ in 0..<counts.additionals { message.additionals.append(try reader.readRecord()) }
        return message
    }
}
