import Foundation
import SystemConfiguration
/// Tracks the DNS servers the network hands out, which stay in the dynamic store even while the local resolver overrides them.
final class UpstreamMonitor: Sendable {
    private static let servicePattern = "State:/Network/Service/.*/DNS"

    private let onChange: @Sendable ([String]) -> Void
    // Written once in start(); SCDynamicStore is not Sendable but is only touched from that call.
    private nonisolated(unsafe) var store: SCDynamicStore?

    init(onChange: @escaping @Sendable ([String]) -> Void) {
        self.onChange = onChange
    }

    static func currentServers() -> [String] {
        guard let store = SCDynamicStoreCreate(nil, "Hostswright" as CFString, nil, nil),
              let keys = SCDynamicStoreCopyKeyList(store, servicePattern as CFString) as? [String]
        else { return [] }
        var servers: [String] = []
        for key in keys.sorted() {
            guard let value = SCDynamicStoreCopyValue(store, key as CFString) as? [String: Any],
                  let addresses = value[kSCPropNetDNSServerAddresses as String] as? [String]
            else { continue }
            for address in addresses where !servers.contains(address) { servers.append(address) }
        }
        return servers
    }

    func start() {
        var context = SCDynamicStoreContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let callback: SCDynamicStoreCallBack = { _, _, info in
            guard let info else { return }
            let monitor = Unmanaged<UpstreamMonitor>.fromOpaque(info).takeUnretainedValue()
            monitor.onChange(UpstreamMonitor.currentServers())
        }
        guard let store = SCDynamicStoreCreate(nil, "Hostswright" as CFString, callback, &context) else { return }
        SCDynamicStoreSetNotificationKeys(store, nil, [Self.servicePattern] as CFArray)
        SCDynamicStoreSetDispatchQueue(store, DispatchQueue(label: "\(helperMachServiceName).upstreams"))
        self.store = store
        onChange(Self.currentServers())
    }
}
