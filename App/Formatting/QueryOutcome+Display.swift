import DNSCore
import SwiftUI

extension QueryOutcome {
    var summary: String {
        switch self {
        case .hosts: "hosts"
        case .cache: "cache"
        case .forwarded(let server): "→ \(Formatters.server(server))"
        case .rule(let server): "rule → \(Formatters.server(server))"
        case .failed(let reason): "failed: \(reason)"
        }
    }

    var tint: Color {
        switch self {
        case .hosts: .green
        case .cache: .blue
        case .forwarded, .rule: .secondary
        case .failed: .red
        }
    }
}

extension Formatters {
    static func server(_ address: String) -> String {
        guard let parsed = ServerAddress(address), parsed.port == ServerAddress.defaultPort else { return address }
        return parsed.host
    }

    static func cacheSummary(_ status: DNSStatus) -> String {
        let entries = status.cacheEntries == 1 ? "1 entry" : "\(status.cacheEntries) entries"
        guard let rate = status.hitRate else { return entries }
        return "\(entries), \(Int((rate * 100).rounded()))% hit rate over \(status.queries) queries"
    }
}
