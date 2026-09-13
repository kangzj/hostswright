import DNSCore
import Foundation
import HostsCore

/// Answers one DNS query at a time from the hosts table, a forwarding rule, the cache, or an upstream server.
actor DNSEngine {
    static let hostsTTL: UInt32 = 5
    private static let logCapacity = 200

    private var table = HostsResolverTable()
    private var cache: DNSCache
    private var settings: DNSSettings
    private var automaticUpstreams: [String] = []
    private var log: [QueryLogEntry] = []
    private var queries = 0
    private let forwarder = Forwarder()

    init(settings: DNSSettings) {
        self.settings = settings
        cache = DNSCache(minimumTTL: settings.minimumTTL, maximumTTL: settings.maximumTTL)
    }

    func update(settings: DNSSettings) {
        self.settings = settings
        cache.minimumTTL = settings.minimumTTL
        cache.maximumTTL = settings.maximumTTL
    }

    func update(automaticUpstreams: [String]) {
        self.automaticUpstreams = automaticUpstreams
    }

    func reloadHosts() {
        let text = (try? String(contentsOfFile: HostsFile.path, encoding: .utf8)) ?? ""
        table = HostsResolverTable(hostsText: text)
        cache.removeAll()
    }

    func clearCache() {
        cache.removeAll()
    }

    var upstreams: [ServerAddress] {
        let hosts: [String] = switch settings.upstream {
        case .automatic: automaticUpstreams
        case .custom(let servers): servers
        }
        return hosts.compactMap(ServerAddress.init).filter { !$0.isLoopback }
    }

    func status(isRunning: Bool, listenError: String?) -> DNSStatus {
        DNSStatus(
            isRunning: isRunning,
            listenError: listenError,
            upstreams: upstreams.map(\.description),
            cacheEntries: cache.count,
            hits: cache.hits,
            misses: cache.misses,
            queries: queries,
            log: log
        )
    }

    func handle(_ data: Data, transport: Forwarder.Transport) async -> Data? {
        guard let id = DNSWire.id(of: data) else { return nil }
        let message: DNSMessage
        do {
            message = try DNSMessage.parse(data)
        } catch {
            return DNSAnswerBuilder.errorResponse(id: id, code: .formatError)
        }
        guard !message.header.isResponse, let question = message.question else {
            return DNSAnswerBuilder.errorResponse(id: id, code: .formatError)
        }
        guard message.header.opcode == 0 else {
            return DNSAnswerBuilder.errorResponse(to: message, code: .notImplemented)
        }
        queries += 1
        let started = ContinuousClock.now
        let (response, outcome) = await resolve(message, raw: data, question: question, transport: transport)
        record(question, outcome: outcome, started: started)
        return response
    }

    private func resolve(_ message: DNSMessage, raw: Data, question: DNSQuestion, transport: Forwarder.Transport) async -> (Data, QueryOutcome) {
        if question.klass == 1, let addresses = table.addresses(for: question.name) {
            return (DNSAnswerBuilder.hostsResponse(to: message, ipv4: addresses.ipv4, ipv6: addresses.ipv6, ttl: Self.hostsTTL), .hosts)
        }
        if let rule = settings.rules.first(where: { $0.matches(question.name) }) {
            let servers = rule.servers.compactMap(ServerAddress.init).filter { !$0.isLoopback }
            return await forward(message, raw: raw, servers: servers, transport: transport, cacheable: false) { .rule(server: $0) }
        }
        if let cached = cache.lookup(question, id: message.header.id, now: Date()) {
            return (cached, .cache)
        }
        return await forward(message, raw: raw, servers: upstreams, transport: transport, cacheable: true) { .forwarded(server: $0) }
    }

    private func forward(
        _ message: DNSMessage,
        raw: Data,
        servers: [ServerAddress],
        transport: Forwarder.Transport,
        cacheable: Bool,
        outcome: (String) -> QueryOutcome
    ) async -> (Data, QueryOutcome) {
        guard !servers.isEmpty else {
            return (DNSAnswerBuilder.errorResponse(to: message, code: .serverFailure), .failed(reason: "No upstream servers"))
        }
        for server in servers {
            guard let response = await forwarder.send(raw, to: server, transport: transport) else { continue }
            if cacheable, let parsed = try? DNSMessage.parse(response) {
                cache.store(parsed, raw: response, now: Date())
            }
            return (DNSWire.settingID(message.header.id, in: response), outcome(server.description))
        }
        return (DNSAnswerBuilder.errorResponse(to: message, code: .serverFailure), .failed(reason: "No upstream answered"))
    }

    private func record(_ question: DNSQuestion, outcome: QueryOutcome, started: ContinuousClock.Instant) {
        guard settings.keepsQueryLog else { return }
        let elapsed = started.duration(to: .now)
        let milliseconds = Int(elapsed.components.seconds * 1000) + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
        log.append(QueryLogEntry(
            time: Date(),
            name: question.name.description,
            type: question.type.description,
            outcome: outcome,
            durationMilliseconds: milliseconds
        ))
        if log.count > Self.logCapacity { log.removeFirst(log.count - Self.logCapacity) }
    }
}
