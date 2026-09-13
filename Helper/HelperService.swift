import Foundation
import HostsCore

final class HelperService: NSObject, HostswrightHelperProtocol {
    private let writer: HostsWriter

    init(writer: HostsWriter) {
        self.writer = writer
    }

    func version(reply: @escaping @Sendable (Int) -> Void) {
        reply(helperProtocolVersion)
    }

    func applyManagedSection(_ section: String?, reply: @escaping @Sendable (String?) -> Void) {
        reply(errorMessage {
            try writer.rewrite { $0.replacingManaged(with: section) }
            try DNSCache.flush()
            log.notice("Applied managed section with \(section?.count ?? 0) characters")
        })
    }

    func removeUnmanagedLines(_ lines: String, reply: @escaping @Sendable (String?) -> Void) {
        let doomed = lines.split(separator: "\n").map(String.init)
        reply(errorMessage {
            try writer.rewrite { $0.removingCustomLines(doomed) }
            try DNSCache.flush()
        })
    }

    func flushDNSCache(reply: @escaping @Sendable (String?) -> Void) {
        reply(errorMessage { try DNSCache.flush() })
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
}
