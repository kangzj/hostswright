import Foundation

public struct IPv4Bytes: Hashable, Sendable, CustomStringConvertible {
    public static let byteCount = 4

    public let octets: [UInt8]

    public init?(octets: [UInt8]) {
        guard octets.count == Self.byteCount else { return nil }
        self.octets = octets
    }

    public init?(_ text: String) {
        var address = in_addr()
        guard inet_pton(AF_INET, text, &address) == 1 else { return nil }
        self.octets = withUnsafeBytes(of: &address, Array.init)
    }

    public var description: String {
        octets.map(String.init).joined(separator: ".")
    }
}

public struct IPv6Bytes: Hashable, Sendable, CustomStringConvertible {
    public static let byteCount = 16

    public let octets: [UInt8]

    public init?(octets: [UInt8]) {
        guard octets.count == Self.byteCount else { return nil }
        self.octets = octets
    }

    public init?(_ text: String) {
        var address = in6_addr()
        guard inet_pton(AF_INET6, text, &address) == 1 else { return nil }
        self.octets = withUnsafeBytes(of: &address, Array.init)
    }

    public var description: String {
        var address = in6_addr()
        withUnsafeMutableBytes(of: &address) { $0.copyBytes(from: octets) }
        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        guard inet_ntop(AF_INET6, &address, &buffer, socklen_t(buffer.count)) != nil else { return "" }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
