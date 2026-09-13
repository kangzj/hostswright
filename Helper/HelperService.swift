import DNSCore
import Foundation
import HostsCore

// Only immutable Sendable state, so Tasks may capture it from the XPC queue.
final class HelperService: NSObject, HostswrightHelperProtocol, @unchecked Sendable {
    private let writer: HostsWriter
    private let dnsMode: DNSMode

    init(writer: HostsWriter, dnsMode: DNSMode) {
        self.writer = writer
        self.dnsMode = dnsMode
    }

    func version(reply: @escaping @Sendable (Int) -> Void) {
        reply(helperProtocolVersion)
    }

    func applyManagedSection(_ section: String?, reply: @escaping @Sendable (String?) -> Void) {
        reply(errorMessage {
            try writer.rewrite { $0.replacingManaged(with: section) }
            try DNSCacheFlush.flush()
            log.notice("Applied managed section with \(section?.count ?? 0) characters")
        })
    }

    func removeUnmanagedLines(_ lines: String, reply: @escaping @Sendable (String?) -> Void) {
        let doomed = lines.split(separator: "\n").map(String.init)
        reply(errorMessage {
            try writer.rewrite { $0.removingCustomLines(doomed) }
            try DNSCacheFlush.flush()
        })
    }

    func flushDNSCache(reply: @escaping @Sendable (String?) -> Void) {
        reply(errorMessage { try DNSCacheFlush.flush() })
    }

    func applyDNSSettings(_ json: String, reply: @escaping @Sendable (String?) -> Void) {
        Task {
            reply(await errorMessage {
                let settings = try JSONDecoder().decode(DNSSettings.self, from: Data(json.utf8))
                try await dnsMode.apply(settings)
            })
        }
    }

    func dnsStatus(reply: @escaping @Sendable (String) -> Void) {
        Task {
            let status = await dnsMode.status()
            let data = (try? JSONEncoder().encode(status)) ?? Data("{}".utf8)
            reply(String(decoding: data, as: UTF8.self))
        }
    }

    func clearResolverCache(reply: @escaping @Sendable (String?) -> Void) {
        Task {
            await dnsMode.clearCache()
            reply(nil)
        }
    }

    private func errorMessage(_ operation: () throws -> Void) -> String? {
        do {
            try operation()
            return nil
        } catch {
            log.error("\(error.localizedDescription)")
            return error.localizedDescription
        }
    }

    private func errorMessage(_ operation: () async throws -> Void) async -> String? {
        do {
            try await operation()
            return nil
        } catch {
            log.error("\(error.localizedDescription)")
            return error.localizedDescription
        }
    }
}
