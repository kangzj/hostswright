import Foundation
import Testing
@testable import DNSCore

@Suite struct DNSAnswerBuilderTests {
    let ipv4 = [IPv4Bytes("10.0.0.1")!, IPv4Bytes("10.0.0.2")!]
    let ipv6 = [IPv6Bytes("fe80::1")!]

    @Test func buildsAuthoritativeARecords() throws {
        let query = try DNSMessage.parse(WireFixtures.query(id: 0x0BAD, name: "Dev.Local", type: .a))
        let response = try DNSMessage.parse(DNSAnswerBuilder.hostsResponse(to: query, ipv4: ipv4, ipv6: ipv6, ttl: 42))
        #expect(response.header.id == 0x0BAD)
        #expect(response.header.isResponse)
        #expect(response.header.isAuthoritative)
        #expect(response.header.recursionAvailable)
        #expect(response.header.recursionDesired)
        #expect(response.header.responseCode == .noError)
        #expect(response.question == query.question)
        #expect(response.answers.count == 2)
        #expect(response.answers.map(\.rdata) == [Data([10, 0, 0, 1]), Data([10, 0, 0, 2])])
        #expect(response.answers.allSatisfy { $0.name == DNSName("dev.local") && $0.type == .a && $0.klass == 1 && $0.ttl == 42 })
        #expect(response.additionals.isEmpty)
    }

    @Test func buildsAAAARecords() throws {
        let query = try DNSMessage.parse(WireFixtures.query(name: "dev.local", type: .aaaa))
        let response = try DNSMessage.parse(DNSAnswerBuilder.hostsResponse(to: query, ipv4: ipv4, ipv6: ipv6, ttl: 5))
        #expect(response.answers.count == 1)
        #expect(response.answers[0].type == .aaaa)
        #expect(response.answers[0].rdata == Data(ipv6[0].octets))
    }

    @Test func returnsNoDataWhenTypeHasNoAddresses() throws {
        let query = try DNSMessage.parse(WireFixtures.query(name: "dev.local", type: .aaaa))
        let response = try DNSMessage.parse(DNSAnswerBuilder.hostsResponse(to: query, ipv4: ipv4, ipv6: [], ttl: 5))
        #expect(response.header.responseCode == .noError)
        #expect(response.header.isAuthoritative)
        #expect(response.answers.isEmpty)
        #expect(response.question == query.question)

        let mx = try DNSMessage.parse(WireFixtures.query(name: "dev.local", type: .mx))
        #expect(try DNSMessage.parse(DNSAnswerBuilder.hostsResponse(to: mx, ipv4: ipv4, ipv6: ipv6, ttl: 5)).answers.isEmpty)
    }

    @Test func copiesRecursionDesiredFromQuery() throws {
        let query = try DNSMessage.parse(WireFixtures.query(recursionDesired: false))
        let response = try DNSMessage.parse(DNSAnswerBuilder.hostsResponse(to: query, ipv4: ipv4, ipv6: [], ttl: 1))
        #expect(!response.header.recursionDesired)
    }

    @Test func buildsErrorResponseEchoingQuestion() throws {
        let query = try DNSMessage.parse(WireFixtures.query(id: 9, name: "example.com"))
        let response = try DNSMessage.parse(DNSAnswerBuilder.errorResponse(to: query, code: .refused))
        #expect(response.header.id == 9)
        #expect(response.header.isResponse)
        #expect(response.header.responseCode == .refused)
        #expect(response.header.recursionAvailable)
        #expect(!response.header.isAuthoritative)
        #expect(response.question == query.question)
        #expect(response.answers.isEmpty)
    }

    @Test func buildsHeaderOnlyErrorResponse() throws {
        let data = DNSAnswerBuilder.errorResponse(id: 77, code: .serverFailure)
        #expect(data.count == DNSHeader.byteCount)
        let response = try DNSMessage.parse(data)
        #expect(response.header.id == 77)
        #expect(response.header.responseCode == .serverFailure)
        #expect(response.questions.isEmpty)
    }

    @Test func parsesAddressText() {
        #expect(IPv4Bytes("192.168.1.10")?.octets == [192, 168, 1, 10])
        #expect(IPv4Bytes("192.168.1.10")?.description == "192.168.1.10")
        #expect(IPv4Bytes("999.1.1.1") == nil)
        #expect(IPv4Bytes("::1") == nil)
        #expect(IPv6Bytes("::1")?.octets == [UInt8](repeating: 0, count: 15) + [1])
        #expect(IPv6Bytes("2606:4700::1111")?.description == "2606:4700::1111")
        #expect(IPv6Bytes("1.2.3.4") == nil)
        #expect(IPv4Bytes(octets: [1, 2, 3]) == nil)
        #expect(IPv6Bytes(octets: [1, 2, 3]) == nil)
    }
}
