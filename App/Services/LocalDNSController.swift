import DNSCore
import Foundation
import Observation

/// Keeps the helper's resolver in step with the user's DNS settings and mirrors its status for the UI.
@MainActor
@Observable
final class LocalDNSController {
    private static let applyDebounce: Duration = .milliseconds(300)
    private static let statusInterval: Duration = .seconds(2)

    var settings: DNSSettings {
        didSet {
            guard settings != oldValue else { return }
            try? store.save(settings)
            scheduleApply()
        }
    }

    private(set) var status: DNSStatus = .stopped
    private(set) var lastError: String?
    private(set) var isApplying = false

    private let helper: HelperClient
    private let store: DNSSettingsStore
    private var applyTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var pageViewers = 0

    init(helper: HelperClient, store: DNSSettingsStore) {
        self.helper = helper
        self.store = store
        settings = store.load()
        updatePolling()
    }

    var isEnabled: Bool { settings.isEnabled }

    func setEnabled(_ enabled: Bool) {
        settings.isEnabled = enabled
    }

    /// The helper enforces the mode itself after a reboot; this re-sends the settings so both sides agree.
    func helperBecameAvailable() {
        scheduleApply()
        updatePolling()
    }

    func helperWillBeRemoved() async {
        guard settings.isEnabled else { return }
        settings.isEnabled = false
        applyTask?.cancel()
        await apply()
    }

    func clearCache() {
        Task {
            await perform { try await helper.clearResolverCache() }
            await refreshStatus()
        }
    }

    func clearError() {
        lastError = nil
    }

    func pageAppeared() {
        pageViewers += 1
        updatePolling()
    }

    func pageDisappeared() {
        pageViewers = max(0, pageViewers - 1)
        updatePolling()
    }

    private func scheduleApply() {
        applyTask?.cancel()
        applyTask = Task { [weak self] in
            try? await Task.sleep(for: Self.applyDebounce)
            guard !Task.isCancelled else { return }
            await self?.apply()
        }
    }

    private func apply() async {
        guard helper.isEnabled else { return }
        isApplying = true
        defer { isApplying = false }
        await perform { try await helper.applyDNSSettings(settings) }
        await refreshStatus()
        if lastError != nil, settings.isEnabled, !status.isRunning {
            settings.isEnabled = false
        }
        updatePolling()
    }

    private func refreshStatus() async {
        guard helper.isEnabled, let latest = try? await helper.dnsStatus() else {
            status = .stopped
            return
        }
        status = latest
    }

    private func updatePolling() {
        let shouldPoll = helper.isEnabled && (pageViewers > 0 || settings.isEnabled)
        if shouldPoll, pollTask == nil {
            pollTask = Task { [weak self] in
                while !Task.isCancelled {
                    await self?.refreshStatus()
                    try? await Task.sleep(for: Self.statusInterval)
                }
            }
        } else if !shouldPoll {
            pollTask?.cancel()
            pollTask = nil
        }
    }

    private func perform(_ operation: () async throws -> Void) async {
        do {
            try await operation()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
