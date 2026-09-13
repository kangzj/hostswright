import Foundation
import Testing
@testable import DNSCore

@Suite struct DNSStatusTests {
    @Test func hitRate() {
        #expect(DNSStatus.stopped.hitRate == nil)
        #expect(DNSStatus(hits: 3, misses: 1).hitRate == 0.75)
        #expect(DNSStatus(hits: 0, misses: 4).hitRate == 0)
    }

    @Test func jsonRoundTripWithLog() throws {
        let status = DNSStatus(
            isRunning: true,
            listenError: nil,
            upstreams: ["1.1.1.1:53"],
            cacheEntries: 4,
            hits: 2,
            misses: 1,
            queries: 3,
            log: [
                QueryLogEntry(time: Date(timeIntervalSince1970: 1), name: "example.com", type: "A", outcome: .hosts, durationMilliseconds: 0),
                QueryLogEntry(time: Date(timeIntervalSince1970: 2), name: "example.org", type: "AAAA", outcome: .forwarded(server: "1.1.1.1:53"), durationMilliseconds: 12),
                QueryLogEntry(time: Date(timeIntervalSince1970: 3), name: "corp.example", type: "A", outcome: .rule(server: "10.0.0.53:53"), durationMilliseconds: 4),
                QueryLogEntry(time: Date(timeIntervalSince1970: 4), name: "down.example", type: "A", outcome: .failed(reason: "timeout"), durationMilliseconds: 2000),
                QueryLogEntry(time: Date(timeIntervalSince1970: 5), name: "example.com", type: "A", outcome: .cache, durationMilliseconds: 0),
            ]
        )
        let data = try JSONEncoder().encode(status)
        #expect(try JSONDecoder().decode(DNSStatus.self, from: data) == status)
    }

    @Test func stoppedDefaults() {
        #expect(DNSStatus.stopped == DNSStatus())
        #expect(!DNSStatus.stopped.isRunning)
        #expect(DNSStatus.stopped.log.isEmpty)
    }
}
