import Foundation

public struct ServerAddress: Hashable, Sendable, CustomStringConvertible {
    public static let defaultPort: UInt16 = 53

    public let host: String
    public let port: UInt16

    public init?(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespaces)
        let host: Substring
        let portText: Substring?
        if text.hasPrefix("[") {
            guard let close = text.firstIndex(of: "]") else { return nil }
            host = text[text.index(after: text.startIndex)..<close]
            let rest = text[text.index(after: close)...]
            if rest.isEmpty {
                portText = nil
            } else {
                guard rest.hasPrefix(":") else { return nil }
                portText = rest.dropFirst()
            }
        } else if text.filter({ $0 == ":" }).count == 1, let colon = text.firstIndex(of: ":") {
            host = text[..<colon]
            portText = text[text.index(after: colon)...]
        } else {
            host = Substring(text)
            portText = nil
        }
        let port: UInt16
        if let portText {
            guard let parsed = UInt16(portText), parsed > 0 else { return nil }
            port = parsed
        } else {
            port = Self.defaultPort
        }
        let hostText = String(host)
        guard IPv4Bytes(hostText) != nil || IPv6Bytes(hostText) != nil else { return nil }
        self.host = hostText
        self.port = port
    }

    public var isIPv6: Bool { host.contains(":") }

    public var isLoopback: Bool {
        if let ipv4 = IPv4Bytes(host) { return ipv4.octets[0] == 127 }
        if let ipv6 = IPv6Bytes(host) { return ipv6.octets == [UInt8](repeating: 0, count: 15) + [1] }
        return false
    }

    public var description: String {
        isIPv6 ? "[\(host)]:\(port)" : "\(host):\(port)"
    }
}
