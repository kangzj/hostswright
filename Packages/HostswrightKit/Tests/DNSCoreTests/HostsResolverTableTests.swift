import Testing
@testable import DNSCore

@Suite struct HostsResolverTableTests {
    let table = HostsResolverTable(hostsText: """
    # comment
    127.0.0.1 localhost Dev.Local api.dev.local
    ::1 localhost
    10.0.0.5 dev.local # second address
    10.0.0.5 dev.local
    bad line here
    """)

    @Test func mapsEveryHostnameOnALine() {
        #expect(table.nameCount == 3)
        #expect(table.addresses(for: DNSName("api.dev.local")!)?.ipv4 == [IPv4Bytes("127.0.0.1")!])
    }

    @Test func mergesAddressesPerNameWithoutDuplicates() throws {
        let addresses = try #require(table.addresses(for: DNSName("dev.local")!))
        #expect(addresses.ipv4 == [IPv4Bytes("127.0.0.1")!, IPv4Bytes("10.0.0.5")!])
        #expect(addresses.ipv6.isEmpty)
    }

    @Test func separatesIPv4AndIPv6() throws {
        let addresses = try #require(table.addresses(for: DNSName("localhost")!))
        #expect(addresses.ipv4 == [IPv4Bytes("127.0.0.1")!])
        #expect(addresses.ipv6 == [IPv6Bytes("::1")!])
    }

    @Test func lookupIsCaseInsensitive() {
        #expect(table.addresses(for: DNSName("DEV.local.")!) != nil)
        #expect(table.addresses(for: DNSName(labels: ["Api", "Dev", "Local"])) != nil)
    }

    @Test func unknownNamesReturnNil() {
        #expect(table.addresses(for: DNSName("nope.local")!) == nil)
        #expect(HostsResolverTable().addresses(for: DNSName("localhost")!) == nil)
        #expect(HostsResolverTable().nameCount == 0)
    }
}
