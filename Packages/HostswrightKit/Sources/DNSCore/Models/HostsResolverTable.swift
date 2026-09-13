import HostsCore

public struct HostsResolverTable: Sendable {
    private struct Addresses {
        var ipv4: [IPv4Bytes] = []
        var ipv6: [IPv6Bytes] = []
    }

    private var entries: [DNSName: Addresses] = [:]

    public init() {}

    public init(hostsText: String) {
        for case .entry(let entry) in HostsSyntax.parse(hostsText) {
            let ipv4 = IPv4Bytes(entry.address)
            let ipv6 = ipv4 == nil ? IPv6Bytes(entry.address) : nil
            guard ipv4 != nil || ipv6 != nil else { continue }
            for hostname in entry.hostnames {
                guard let name = DNSName(hostname) else { continue }
                var addresses = entries[name, default: Addresses()]
                if let ipv4, !addresses.ipv4.contains(ipv4) { addresses.ipv4.append(ipv4) }
                if let ipv6, !addresses.ipv6.contains(ipv6) { addresses.ipv6.append(ipv6) }
                entries[name] = addresses
            }
        }
    }

    public func addresses(for name: DNSName) -> (ipv4: [IPv4Bytes], ipv6: [IPv6Bytes])? {
        entries[name].map { ($0.ipv4, $0.ipv6) }
    }

    public var nameCount: Int { entries.count }
}
