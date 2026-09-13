import Foundation
import Network
import Synchronization
import os
/// Listens on 127.0.0.1:53 over UDP and TCP and hands every query to the engine.
final class DNSServer: Sendable {
    struct StartError: LocalizedError {
        let errorDescription: String?
    }

    static let port: UInt16 = 53
    private static let maximumTCPMessage = 65_535

    private let engine: DNSEngine
    private let queue = DispatchQueue(label: "\(helperMachServiceName).dns")
    private let listeners = Mutex<[NWListener]>([])
    private let logger = Logger(subsystem: appBundleIdentifier, category: "DNSServer")

    init(engine: DNSEngine) {
        self.engine = engine
    }

    func start() async throws {
        let udp = try makeListener(parameters: .udp)
        let tcp = try makeListener(parameters: .tcp)
        listeners.withLock { $0 = [udp, tcp] }
        for listener in [udp, tcp] {
            try await ready(listener)
        }
        logger.notice("DNS server listening on 127.0.0.1:\(Self.port)")
    }

    func stop() {
        let active = listeners.withLock { listeners in
            defer { listeners = [] }
            return listeners
        }
        active.forEach { $0.cancel() }
        if !active.isEmpty { logger.notice("DNS server stopped") }
    }

    private func makeListener(parameters: NWParameters) throws -> NWListener {
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: Self.port)!)
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters)
        let isTCP = parameters.defaultProtocolStack.transportProtocol is NWProtocolTCP.Options
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return connection.cancel() }
            connection.start(queue: queue)
            if isTCP {
                serveTCP(connection)
            } else {
                serveUDP(connection)
            }
        }
        return listener
    }

    private func ready(_ listener: NWListener) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let settled = Mutex(false)
            listener.stateUpdateHandler = { state in
                let message: Result<Void, any Error>? = switch state {
                case .ready: .success(())
                case .failed(let error): .failure(StartError(errorDescription: Self.describe(error)))
                case .cancelled: .failure(StartError(errorDescription: "Listener cancelled"))
                default: nil
                }
                guard let message, !settled.withLock({ settled in
                    defer { settled = true }
                    return settled
                }) else { return }
                continuation.resume(with: message)
            }
            listener.start(queue: queue)
        }
    }

    private static func describe(_ error: NWError) -> String {
        if case .posix(let code) = error, code == .EADDRINUSE {
            return "Port \(port) is already in use by another DNS server."
        }
        if case .posix(let code) = error, code == .EACCES {
            return "Not allowed to bind port \(port)."
        }
        return error.localizedDescription
    }

    private func serveUDP(_ connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, _ in
            guard let self, let data else { return connection.cancel() }
            Task {
                let response = await self.engine.handle(data, transport: .udp)
                guard let response else { return connection.cancel() }
                connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
            }
        }
    }

    private func serveTCP(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 2, maximumLength: 2) { [weak self] header, _, isComplete, error in
            guard let self, let header, header.count == 2, error == nil else { return connection.cancel() }
            let length = Int(header[header.startIndex]) << 8 | Int(header[header.startIndex + 1])
            guard length > 0, length <= Self.maximumTCPMessage else { return connection.cancel() }
            connection.receive(minimumIncompleteLength: length, maximumLength: length) { body, _, _, error in
                guard let body, error == nil else { return connection.cancel() }
                Task {
                    let response = await self.engine.handle(body, transport: .tcp)
                    guard let response else { return connection.cancel() }
                    connection.send(content: Forwarder.lengthPrefixed(response), completion: .contentProcessed { _ in
                        if isComplete { connection.cancel() } else { self.serveTCP(connection) }
                    })
                }
            }
        }
    }
}
