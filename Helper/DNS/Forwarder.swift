import DNSCore
import Foundation
import Network
import Synchronization
/// Relays one raw DNS query to one server and returns the raw answer, or nil after the timeout.
final class Forwarder: Sendable {
    enum Transport: Sendable {
        case udp
        case tcp
    }

    private static let timeout: Duration = .seconds(2)
    private let queue = DispatchQueue(label: "\(helperMachServiceName).forwarder", attributes: .concurrent)

    func send(_ query: Data, to server: ServerAddress, transport: Transport) async -> Data? {
        guard let host = IPv4Address(server.host).map(NWEndpoint.Host.ipv4) ?? IPv6Address(server.host).map(NWEndpoint.Host.ipv6),
              let port = NWEndpoint.Port(rawValue: server.port)
        else { return nil }
        let endpoint = NWEndpoint.hostPort(host: host, port: port)
        let parameters: NWParameters = transport == .udp ? .udp : .tcp
        let connection = NWConnection(to: endpoint, using: parameters)
        defer { connection.cancel() }
        return await withTaskGroup(of: Data?.self) { group in
            group.addTask { await self.exchange(query, over: connection, transport: transport) }
            group.addTask {
                try? await Task.sleep(for: Self.timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private func exchange(_ query: Data, over connection: NWConnection, transport: Transport) async -> Data? {
        let reply = SingleReply()
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                let payload = transport == .tcp ? Self.lengthPrefixed(query) : query
                connection.send(content: payload, completion: .contentProcessed { error in
                    if error != nil { reply.settle(nil) }
                })
                Self.receive(over: connection, transport: transport) { reply.settle($0) }
            case .failed, .cancelled:
                reply.settle(nil)
            default:
                break
            }
        }
        connection.start(queue: queue)
        return await reply.value()
    }

    private static func receive(over connection: NWConnection, transport: Transport, completion: @escaping @Sendable (Data?) -> Void) {
        switch transport {
        case .udp:
            connection.receiveMessage { data, _, _, _ in completion(data) }
        case .tcp:
            connection.receive(minimumIncompleteLength: 2, maximumLength: 2) { header, _, _, _ in
                guard let header, header.count == 2 else { return completion(nil) }
                let length = Int(header[header.startIndex]) << 8 | Int(header[header.startIndex + 1])
                guard length > 0 else { return completion(nil) }
                connection.receive(minimumIncompleteLength: length, maximumLength: length) { body, _, _, _ in
                    completion(body)
                }
            }
        }
    }

    static func lengthPrefixed(_ message: Data) -> Data {
        var framed = Data([UInt8(message.count >> 8), UInt8(message.count & 0xFF)])
        framed.append(message)
        return framed
    }
}

/// Bridges the first of several possible Network callbacks into one async result.
private final class SingleReply: Sendable {
    private let state = Mutex<(continuation: CheckedContinuation<Data?, Never>?, result: Data??)>((nil, nil))

    func settle(_ data: Data?) {
        let continuation = state.withLock { state -> CheckedContinuation<Data?, Never>? in
            guard state.result == nil else { return nil }
            state.result = .some(data)
            defer { state.continuation = nil }
            return state.continuation
        }
        continuation?.resume(returning: data)
    }

    func value() async -> Data? {
        await withCheckedContinuation { continuation in
            let settled = state.withLock { state -> Data?? in
                if let result = state.result { return result }
                state.continuation = continuation
                return nil
            }
            if let settled { continuation.resume(returning: settled) }
        }
    }
}
