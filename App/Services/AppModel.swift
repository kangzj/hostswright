import AppKit
import Foundation
import HostsCore
import Observation

@MainActor
@Observable
final class AppModel {
    private static let saveDebounce: Duration = .milliseconds(500)
    private static let approvalPollInterval: Duration = .seconds(1)

    var configuration: AppConfiguration {
        didSet {
            guard configuration != oldValue else { return }
            scheduleSave()
            sync.setDesired(configuration.managedSection)
        }
    }

    let helper = HelperClient()
    let hostsFile = HostsFileMonitor()
    let sync: HostsSync
    let dns: LocalDNSController
    let isFirstLaunch: Bool
    private(set) var helperInstallError: String?
    private(set) var lastActionError: String?

    private let store: ConfigurationStore
    private var saveTask: Task<Void, Never>?
    private var approvalTask: Task<Void, Never>?

    init(store: ConfigurationStore = ConfigurationStore(directory: ConfigurationStore.defaultDirectory)) {
        self.store = store
        isFirstLaunch = !store.exists
        let loaded = store.load()
        configuration = loaded
        sync = HostsSync(helper: helper, monitor: hostsFile, desired: loaded.managedSection)
        dns = LocalDNSController(helper: helper, store: DNSSettingsStore(directory: ConfigurationStore.defaultDirectory))
        if helper.isEnabled {
            sync.applyIfOutOfSync()
        } else if helper.status == .requiresApproval {
            pollForApproval()
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { [weak self] in self?.refreshHelperStatus() }
        }
    }

    var opensWindowAtLaunch: Bool { isFirstLaunch || !helper.isEnabled }

    var hasActiveGroups: Bool { !configuration.enabledGroups.isEmpty }

    // MARK: Groups

    @discardableResult
    func addGroup(name: String = "New Group", content: String = "", isEnabled: Bool = false) -> UUID {
        let group = HostsGroup(name: configuration.uniqueName(basedOn: name), content: content, isEnabled: isEnabled)
        configuration.groups.append(group)
        return group.id
    }

    func deleteGroup(id: UUID) {
        configuration.remove(id: id)
    }

    func moveGroups(from source: IndexSet, to destination: Int) {
        configuration.groups.move(fromOffsets: source, toOffset: destination)
    }

    func setEnabled(_ enabled: Bool, id: UUID) {
        configuration.update(id: id) { $0.isEnabled = enabled }
    }

    func disableAll() {
        for index in configuration.groups.indices { configuration.groups[index].isEnabled = false }
    }

    /// Adopts entries left in /etc/hosts by another tool: each blank-line-separated block becomes an enabled group.
    func importFromHostsFile() async -> [UUID] {
        let file = hostsFile.file
        let imported = ImportedGroups.groups(from: file).map { group in
            var group = group
            group.name = configuration.uniqueName(basedOn: group.name)
            return group
        }
        guard !imported.isEmpty else { return [] }
        configuration.groups.append(contentsOf: imported)
        await perform { try await helper.removeUnmanagedLines(file.customLines) }
        return imported.map(\.id)
    }

    func flushDNSCache() async {
        await perform { try await helper.flushDNSCache() }
    }

    func clearActionError() {
        lastActionError = nil
    }

    private func perform(_ operation: () async throws -> Void) async {
        do {
            try await operation()
            lastActionError = nil
        } catch {
            lastActionError = error.localizedDescription
        }
    }

    // MARK: Helper lifecycle

    func refreshHelperStatus() {
        let wasEnabled = helper.isEnabled
        helper.refreshStatus()
        if helper.isEnabled, !wasEnabled {
            approvalTask?.cancel()
            sync.applyIfOutOfSync()
            dns.helperBecameAvailable()
        }
    }

    func installHelper() {
        Task {
            if helper.isEnabled { await removeHelper() }
            guard helperInstallError == nil else { return }
            let error = await registerHelperWithRetry()
            refreshHelperStatus()
            // register() reports an error while the registration is only waiting for approval; the status is the truth.
            helperInstallError = helper.status == .notRegistered ? error : nil
            if helper.status == .requiresApproval { pollForApproval() }
        }
    }

    func removeHelper() async {
        await dns.helperWillBeRemoved()
        do {
            try await helper.unregister()
            helperInstallError = nil
        } catch {
            helperInstallError = error.localizedDescription
        }
    }

    // Service Management rejects a registration that lands while the previous one is still being torn down.
    private func registerHelperWithRetry(attempts: Int = 4) async -> String? {
        for attempt in 1...attempts {
            do {
                try helper.register()
                return nil
            } catch {
                if attempt == attempts { return error.localizedDescription }
                try? await Task.sleep(for: .seconds(1))
            }
        }
        return nil
    }

    // Login Items approval happens in System Settings, so poll until it lands and the app can move on by itself.
    private func pollForApproval() {
        approvalTask?.cancel()
        approvalTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.approvalPollInterval)
                guard let self else { return }
                refreshHelperStatus()
                if helper.status != .requiresApproval { return }
            }
        }
    }

    // MARK: Persistence

    func saveNow() {
        saveTask?.cancel()
        try? store.save(configuration)
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: Self.saveDebounce)
            guard let self, !Task.isCancelled else { return }
            try? store.save(configuration)
        }
    }
}
