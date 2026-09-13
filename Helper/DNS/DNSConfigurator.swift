import Foundation
import SystemConfiguration

/// Points every network service at the local resolver and puts the previous DNS configuration back afterwards.
enum DNSConfigurator {
    struct ConfigurationError: LocalizedError {
        let errorDescription: String?
    }

    typealias SavedConfiguration = [String: [String: [String]]]

    static let localResolver = "127.0.0.1"

    /// Returns the per-service DNS configuration that was in place, keyed by service ID, for `restore`.
    static func pointAtLocalResolver() throws -> SavedConfiguration {
        var saved: SavedConfiguration = [:]
        try modifyServices { service, protocolConfiguration in
            let id = SCNetworkServiceGetServiceID(service) as String? ?? ""
            saved[id] = Self.stringLists(in: protocolConfiguration)
            var updated = protocolConfiguration ?? [:]
            updated[kSCPropNetDNSServerAddresses as String] = [localResolver]
            return .replace(updated)
        }
        return saved
    }

    static func restore(_ saved: SavedConfiguration) throws {
        try modifyServices { service, protocolConfiguration in
            let id = SCNetworkServiceGetServiceID(service) as String? ?? ""
            guard var updated = protocolConfiguration else { return .keep }
            if let addresses = (saved[id] ?? [:])[kSCPropNetDNSServerAddresses as String] {
                updated[kSCPropNetDNSServerAddresses as String] = addresses
            } else {
                updated.removeValue(forKey: kSCPropNetDNSServerAddresses as String)
            }
            return updated.isEmpty ? .clear : .replace(updated)
        }
    }

    private enum Change {
        case keep
        case clear
        case replace([String: Any])
    }

    private static func modifyServices(_ change: (SCNetworkService, [String: Any]?) -> Change) throws {
        guard let preferences = SCPreferencesCreate(nil, "Hostswright" as CFString, nil) else {
            throw ConfigurationError(errorDescription: "Could not open network preferences.")
        }
        guard SCPreferencesLock(preferences, true) else {
            throw ConfigurationError(errorDescription: "Network preferences are locked by another process.")
        }
        defer { SCPreferencesUnlock(preferences) }
        guard let set = SCNetworkSetCopyCurrent(preferences),
              let services = SCNetworkSetCopyServices(set) as? [SCNetworkService]
        else {
            throw ConfigurationError(errorDescription: "No active network location.")
        }
        for service in services where SCNetworkServiceGetEnabled(service) {
            guard let dns = SCNetworkServiceCopyProtocol(service, kSCNetworkProtocolTypeDNS) else { continue }
            let current = SCNetworkProtocolGetConfiguration(dns) as? [String: Any]
            let replacement: CFDictionary?
            switch change(service, current) {
            case .keep: continue
            case .clear: replacement = nil
            case .replace(let updated): replacement = updated as CFDictionary
            }
            guard SCNetworkProtocolSetConfiguration(dns, replacement) else {
                throw ConfigurationError(errorDescription: "Could not update DNS for \(SCNetworkServiceGetName(service) as String? ?? "a network service").")
            }
        }
        guard SCPreferencesCommitChanges(preferences), SCPreferencesApplyChanges(preferences) else {
            throw ConfigurationError(errorDescription: "Could not apply the network configuration: \(SCErrorString(SCError()))")
        }
    }

    private static func stringLists(in configuration: [String: Any]?) -> [String: [String]] {
        var lists: [String: [String]] = [:]
        for (key, value) in configuration ?? [:] {
            if let strings = value as? [String] { lists[key] = strings }
        }
        return lists
    }
}
