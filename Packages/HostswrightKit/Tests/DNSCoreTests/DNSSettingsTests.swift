import Foundation
import Testing
@testable import DNSCore

@Suite struct DNSSettingsTests {
    @Test func jsonRoundTrip() throws {
        let settings = DNSSettings(
            isEnabled: true,
            upstream: .custom(["1.1.1.1", "[2606:4700::1111]:53"]),
            minimumTTL: 10,
            maximumTTL: 600,
            rules: [ForwardingRule(domain: "corp.example", servers: ["10.0.0.53"])],
            keepsQueryLog: false
        )
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(DNSSettings.self, from: data) == settings)
    }

    @Test func decodesEmptyObjectAsDefaults() throws {
        let decoded = try JSONDecoder().decode(DNSSettings.self, from: Data("{}".utf8))
        #expect(decoded == .default)
        #expect(decoded.isEnabled == false)
        #expect(decoded.upstream == .automatic)
        #expect(decoded.minimumTTL == 30)
        #expect(decoded.maximumTTL == 3600)
        #expect(decoded.rules.isEmpty)
        #expect(decoded.keepsQueryLog)
    }

    @Test func decodesPartialObject() throws {
        let json = #"{"isEnabled":true,"upstream":{"custom":{"_0":["9.9.9.9"]}}}"#
        let decoded = try JSONDecoder().decode(DNSSettings.self, from: Data(json.utf8))
        #expect(decoded.isEnabled)
        #expect(decoded.upstream == .custom(["9.9.9.9"]))
        #expect(decoded.maximumTTL == 3600)
    }

    @Test func ruleMatchesSuffixOnly() throws {
        let rule = ForwardingRule(domain: " Corp.Example. ", servers: [])
        #expect(rule.matches(DNSName("corp.example")!))
        #expect(rule.matches(DNSName("vpn.CORP.example")!))
        #expect(!rule.matches(DNSName("notcorp.example")!))
        #expect(!rule.matches(DNSName("example")!))
        #expect(ForwardingRule(domain: ".corp.example", servers: []).matches(DNSName("a.corp.example")!))
    }

    @Test func ruleTreatsWildcardAsLiteralLabel() throws {
        let rule = ForwardingRule(domain: "*.corp.example", servers: [])
        #expect(!rule.matches(DNSName("corp.example")!))
        #expect(!rule.matches(DNSName("a.corp.example")!))
        #expect(rule.matches(DNSName(labels: ["b", "*", "corp", "example"])))
    }

    @Test func invalidRuleDomainNeverMatches() {
        #expect(!ForwardingRule(domain: "", servers: []).matches(DNSName("example")!))
        #expect(!ForwardingRule(domain: "a..b", servers: []).matches(DNSName("a.b")!))
    }
}

@Suite struct ServerAddressTests {
    @Test func parsesIPv4WithDefaultAndExplicitPort() {
        #expect(ServerAddress("1.1.1.1")?.host == "1.1.1.1")
        #expect(ServerAddress("1.1.1.1")?.port == 53)
        #expect(ServerAddress("1.1.1.1:5353")?.port == 5353)
        #expect(ServerAddress("1.1.1.1:5353")?.description == "1.1.1.1:5353")
    }

    @Test func parsesIPv6WithAndWithoutBrackets() {
        let bare = ServerAddress("2606:4700::1111")
        #expect(bare?.host == "2606:4700::1111")
        #expect(bare?.port == 53)
        #expect(bare?.description == "[2606:4700::1111]:53")
        let bracketed = ServerAddress("[2606:4700::1111]:5353")
        #expect(bracketed?.host == "2606:4700::1111")
        #expect(bracketed?.port == 5353)
        #expect(ServerAddress("[::1]")?.port == 53)
    }

    @Test func rejectsInvalidInput() {
        #expect(ServerAddress("dns.example") == nil)
        #expect(ServerAddress("1.1.1.1:0") == nil)
        #expect(ServerAddress("1.1.1.1:70000") == nil)
        #expect(ServerAddress("1.1.1.1:abc") == nil)
        #expect(ServerAddress("[::1") == nil)
        #expect(ServerAddress("[::1]x") == nil)
        #expect(ServerAddress("") == nil)
    }

    @Test func detectsLoopback() {
        #expect(ServerAddress("127.0.0.1")?.isLoopback == true)
        #expect(ServerAddress("127.5.5.5:53")?.isLoopback == true)
        #expect(ServerAddress("[::1]:53")?.isLoopback == true)
        #expect(ServerAddress("10.0.0.1")?.isLoopback == false)
        #expect(ServerAddress("::2")?.isLoopback == false)
    }
}
