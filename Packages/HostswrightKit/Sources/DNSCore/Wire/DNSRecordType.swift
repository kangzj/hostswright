public struct DNSRecordType: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public static let a = DNSRecordType(rawValue: 1)
    public static let ns = DNSRecordType(rawValue: 2)
    public static let cname = DNSRecordType(rawValue: 5)
    public static let soa = DNSRecordType(rawValue: 6)
    public static let ptr = DNSRecordType(rawValue: 12)
    public static let mx = DNSRecordType(rawValue: 15)
    public static let txt = DNSRecordType(rawValue: 16)
    public static let aaaa = DNSRecordType(rawValue: 28)
    public static let srv = DNSRecordType(rawValue: 33)
    public static let opt = DNSRecordType(rawValue: 41)
    public static let https = DNSRecordType(rawValue: 65)
    public static let any = DNSRecordType(rawValue: 255)

    private static let names: [UInt16: String] = [
        1: "A", 2: "NS", 5: "CNAME", 6: "SOA", 12: "PTR", 15: "MX", 16: "TXT",
        28: "AAAA", 33: "SRV", 41: "OPT", 65: "HTTPS", 255: "ANY",
    ]

    public var description: String {
        Self.names[rawValue] ?? "TYPE\(rawValue)"
    }
}
