import Foundation
import HostsCore
import Observation

/// Drives /etc/hosts toward the configuration's managed section and reports how far apart the two are.
@MainActor
@Observable
final class HostsSync {
    enum State: Equatable {
        case synced
        case pending
        case applying
        case outOfSync
        case failed(String)
    }

    private static let debounce: Duration = .milliseconds(400)

    private(set) var state: State = .synced
    private(set) var desired: String?

    private let helper: HelperClient
    private let monitor: HostsFileMonitor
    private var debounceTask: Task<Void, Never>?
    private var applyInProgress = false
    private var applyRequested = false

    init(helper: HelperClient, monitor: HostsFileMonitor, desired: String?) {
        self.helper = helper
        self.monitor = monitor
        self.desired = desired
        monitor.onChange = { [weak self] file in self?.reconcile(with: file) }
        reconcile(with: monitor.file)
    }

    var needsAttention: Bool {
        switch state {
        case .outOfSync, .failed: true
        case .synced, .pending, .applying: false
        }
    }

    func setDesired(_ section: String?) {
        guard section != desired else { return }
        desired = section
        state = .pending
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled else { return }
            await self?.apply()
        }
    }

    func reapply() {
        debounceTask?.cancel()
        Task { await apply() }
    }

    func applyIfOutOfSync() {
        guard state == .outOfSync || monitor.file.managed != desired else { return }
        reapply()
    }

    private func apply() async {
        guard helper.isEnabled else {
            reconcile(with: monitor.file)
            return
        }
        if applyInProgress {
            applyRequested = true
            return
        }
        applyInProgress = true
        defer { applyInProgress = false }
        repeat {
            applyRequested = false
            let target = desired
            state = .applying
            do {
                try await helper.applyManagedSection(target)
                monitor.reload()
                state = monitor.file.managed == target ? .synced : .outOfSync
            } catch {
                state = .failed(error.localizedDescription)
            }
        } while applyRequested
    }

    // A failure message stays visible until the file matches again; every other state follows the file.
    private func reconcile(with file: HostsFile) {
        guard !applyInProgress else { return }
        let matches = file.managed == desired
        if case .failed = state, !matches { return }
        state = matches ? .synced : .outOfSync
    }
}
