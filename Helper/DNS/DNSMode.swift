import DNSCore
import Foundation
import os

/// Owns the resolver's lifecycle and persists enough state to bring it back after a reboot.
actor DNSMode {
    private struct PersistedState: Codable {
        var settings: DNSSettings
        var savedConfiguration: DNSConfigurator.SavedConfiguration?
    }

    private static let stateURL = URL(fileURLWithPath: "/Library/Application Support/Hostswright/dns-state.json")

    private let engine: DNSEngine
    private let server: DNSServer
    private var state: PersistedState
    private var isRunning = false
    private var listenError: String?
    private var monitor: UpstreamMonitor?
    private let logger = Logger(subsystem: appBundleIdentifier, category: "DNSMode")

    init() {
        state = Self.loadState() ?? PersistedState(settings: .default, savedConfiguration: nil)
        engine = DNSEngine(settings: state.settings)
        server = DNSServer(engine: engine)
    }

    var settings: DNSSettings { state.settings }

    func restoreAfterLaunch() async {
        guard state.settings.isEnabled else { return }
        logger.notice("Restoring local DNS mode from saved state")
        do {
            try await start()
        } catch {
            logger.error("Could not restore local DNS mode: \(error.localizedDescription)")
        }
    }

    func apply(_ settings: DNSSettings) async throws {
        let wasEnabled = state.settings.isEnabled
        state.settings = settings
        await engine.update(settings: settings)
        if settings.isEnabled, !isRunning {
            try await start()
        } else if !settings.isEnabled, wasEnabled || isRunning {
            try stop()
        }
        try saveState()
    }

    func hostsDidChange() async {
        await engine.reloadHosts()
    }

    func clearCache() async {
        await engine.clearCache()
    }

    func status() async -> DNSStatus {
        await engine.status(isRunning: isRunning, listenError: listenError)
    }

    private func start() async throws {
        await engine.reloadHosts()
        let monitor = UpstreamMonitor { [engine] servers in
            Task { await engine.update(automaticUpstreams: servers) }
        }
        monitor.start()
        self.monitor = monitor
        do {
            try await server.start()
        } catch {
            listenError = error.localizedDescription
            self.monitor = nil
            state.settings.isEnabled = false
            try? saveState()
            throw error
        }
        listenError = nil
        isRunning = true
        if state.savedConfiguration == nil {
            state.savedConfiguration = try DNSConfigurator.pointAtLocalResolver()
        }
        try DNSCacheFlush.flush()
        logger.notice("Local DNS mode on")
    }

    private func stop() throws {
        server.stop()
        monitor = nil
        isRunning = false
        if let saved = state.savedConfiguration {
            try DNSConfigurator.restore(saved)
            state.savedConfiguration = nil
        }
        try DNSCacheFlush.flush()
        logger.notice("Local DNS mode off")
    }

    private static func loadState() -> PersistedState? {
        guard let data = try? Data(contentsOf: stateURL) else { return nil }
        return try? JSONDecoder().decode(PersistedState.self, from: data)
    }

    private func saveState() throws {
        try FileManager.default.createDirectory(at: Self.stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: Self.stateURL, options: .atomic)
    }
}
