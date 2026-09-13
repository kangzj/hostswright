import Foundation
import Observation
import ServiceManagement
import Synchronization

@MainActor
@Observable
final class HelperClient {
    enum Status: Equatable {
        case unsignedBuild
        case notRegistered
        case requiresApproval
        case enabled
    }

    enum ClientError: LocalizedError {
        case helperNotEnabled
        case timedOut
        case remote(String)
        case transport(String)

        var errorDescription: String? {
            switch self {
            case .helperNotEnabled: "HostsMaster is not set up yet."
            case .timedOut: "The helper did not respond."
            case .remote(let message), .transport(let message): message
            }
        }
    }

    static let callTimeout: Duration = .seconds(3)

    private(set) var status: Status = .notRegistered
    private let service = SMAppService.daemon(plistName: "\(helperMachServiceName).plist")
    private var connection: NSXPCConnection?

    init() {
        refreshStatus()
    }

    var isEnabled: Bool { status == .enabled }

    func refreshStatus() {
        guard CodeSigningInfo.teamIdentifier() != nil else {
            status = .unsignedBuild
            return
        }
        status = switch service.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        default: .notRegistered
        }
    }

    func register() throws {
        try service.register()
        refreshStatus()
        if status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    func unregister() async throws {
        try await service.unregister()
        invalidateConnection()
        refreshStatus()
    }

    func applyManagedSection(_ section: String?) async throws {
        try await callExpectingNoError { proxy, reply in proxy.applyManagedSection(section, reply: reply) }
    }

    func removeUnmanagedLines(_ lines: [String]) async throws {
        try await callExpectingNoError { proxy, reply in proxy.removeUnmanagedLines(lines.joined(separator: "\n"), reply: reply) }
    }

    func flushDNSCache() async throws {
        try await callExpectingNoError { proxy, reply in proxy.flushDNSCache(reply: reply) }
    }

    func version() async throws -> Int {
        try await call { proxy, reply in proxy.version(reply: reply) }
    }

    private func callExpectingNoError(
        _ invoke: (HostsMasterHelperProtocol, @escaping @Sendable (String?) -> Void) -> Void
    ) async throws {
        if let message: String = try await call(invoke) {
            throw ClientError.remote(message)
        }
    }

    private func call<Reply: Sendable>(
        _ invoke: (HostsMasterHelperProtocol, @escaping @Sendable (Reply) -> Void) -> Void
    ) async throws -> Reply {
        guard isEnabled else { throw ClientError.helperNotEnabled }
        let connection = activeConnection()
        return try await withCheckedThrowingContinuation { continuation in
            let reply = PendingReply(continuation)
            let proxy = connection.remoteObjectProxyWithErrorHandler { @Sendable error in
                reply.settle(.failure(ClientError.transport(error.localizedDescription)))
            } as! HostsMasterHelperProtocol
            invoke(proxy) { value in reply.settle(.success(value)) }
            reply.startTimeout(Self.callTimeout)
        }
    }

    private func activeConnection() -> NSXPCConnection {
        if let connection { return connection }
        let connection = NSXPCConnection(machServiceName: helperMachServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: HostsMasterHelperProtocol.self)
        connection.invalidationHandler = { [weak self] in
            Task { @MainActor in self?.connection = nil }
        }
        connection.resume()
        self.connection = connection
        return connection
    }

    private func invalidateConnection() {
        connection?.invalidate()
        connection = nil
    }
}

// XPC replies and errors arrive on arbitrary threads; this box keeps the continuation off the main actor and resumes it once.
private final class PendingReply<Reply: Sendable>: Sendable {
    private struct State {
        var continuation: CheckedContinuation<Reply, any Error>?
        var timeout: Task<Void, Never>?
    }

    private let state: Mutex<State>

    init(_ continuation: CheckedContinuation<Reply, any Error>) {
        state = Mutex(State(continuation: continuation))
    }

    func startTimeout(_ duration: Duration) {
        let task = Task { [self] in
            guard (try? await Task.sleep(for: duration)) != nil else { return }
            settle(.failure(HelperClient.ClientError.timedOut))
        }
        state.withLock { $0.timeout = task }
    }

    func settle(_ result: Result<Reply, any Error>) {
        let pending = state.withLock { state in
            defer { state = State() }
            return state
        }
        pending.timeout?.cancel()
        pending.continuation?.resume(with: result)
    }
}
