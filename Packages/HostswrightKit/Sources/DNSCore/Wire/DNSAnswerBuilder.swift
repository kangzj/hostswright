import Foundation

public enum DNSAnswerBuilder {
    public static func hostsResponse(to query: DNSMessage, ipv4: [IPv4Bytes], ipv6: [IPv6Bytes], ttl: UInt32) -> Data {
        let rdatas: [[UInt8]]
        switch query.question?.type {
        case .a?: rdatas = ipv4.map(\.octets)
        case .aaaa?: rdatas = ipv6.map(\.octets)
        default: rdatas = []
        }
        var writer = DNSWireWriter()
        writer.append(responseHeader(to: query, isAuthoritative: true, code: .noError), questions: query.questions.count, answers: rdatas.count)
        for question in query.questions { writer.append(question) }
        if let question = query.question {
            for rdata in rdatas {
                writer.append(question.name)
                writer.append(question.type.rawValue)
                writer.append(question.klass)
                writer.append(ttl)
                writer.append(UInt16(rdata.count))
                writer.append(rdata)
            }
        }
        return writer.data
    }

    public static func errorResponse(to query: DNSMessage, code: DNSResponseCode) -> Data {
        var writer = DNSWireWriter()
        writer.append(responseHeader(to: query, isAuthoritative: false, code: code), questions: query.questions.count, answers: 0)
        for question in query.questions { writer.append(question) }
        return writer.data
    }

    public static func errorResponse(id: UInt16, code: DNSResponseCode) -> Data {
        var writer = DNSWireWriter()
        writer.append(DNSHeader(id: id, isResponse: true, recursionAvailable: true, responseCode: code), questions: 0, answers: 0)
        return writer.data
    }

    private static func responseHeader(to query: DNSMessage, isAuthoritative: Bool, code: DNSResponseCode) -> DNSHeader {
        DNSHeader(
            id: query.header.id,
            isResponse: true,
            opcode: query.header.opcode,
            isAuthoritative: isAuthoritative,
            recursionDesired: query.header.recursionDesired,
            recursionAvailable: true,
            responseCode: code
        )
    }
}
