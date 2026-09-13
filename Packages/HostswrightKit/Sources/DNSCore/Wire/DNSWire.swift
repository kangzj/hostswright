import Foundation

public enum DNSWire {
    public static func settingID(_ id: UInt16, in data: Data) -> Data {
        var bytes = [UInt8](data)
        write(id: id, into: &bytes)
        return Data(bytes)
    }

    public static func adjusting(_ data: Data, id: UInt16, records: [DNSRecordSummary], elapsed: UInt32) -> Data {
        rewritingTTLs(in: data, id: id, records: records) { ttl in ttl > elapsed ? ttl - elapsed : 0 }
    }

    static func rewritingTTLs(in data: Data, id: UInt16, records: [DNSRecordSummary], _ transform: (UInt32) -> UInt32) -> Data {
        var bytes = [UInt8](data)
        write(id: id, into: &bytes)
        for record in records where record.ttlOffset >= 0 && record.ttlOffset + 4 <= bytes.count {
            let offset = record.ttlOffset
            let current = UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16 | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
            let updated = transform(current)
            bytes[offset] = UInt8(updated >> 24)
            bytes[offset + 1] = UInt8((updated >> 16) & 0xFF)
            bytes[offset + 2] = UInt8((updated >> 8) & 0xFF)
            bytes[offset + 3] = UInt8(updated & 0xFF)
        }
        return Data(bytes)
    }

    public static func header(of data: Data) -> DNSHeader? {
        guard data.count >= DNSHeader.byteCount else { return nil }
        var reader = DNSWireReader(bytes: [UInt8](data.prefix(DNSHeader.byteCount)))
        return try? reader.readHeader()
    }

    public static func id(of data: Data) -> UInt16? {
        guard data.count >= 2 else { return nil }
        let bytes = [UInt8](data.prefix(2))
        return UInt16(bytes[0]) << 8 | UInt16(bytes[1])
    }

    private static func write(id: UInt16, into bytes: inout [UInt8]) {
        guard bytes.count >= 2 else { return }
        bytes[0] = UInt8(id >> 8)
        bytes[1] = UInt8(id & 0xFF)
    }
}
