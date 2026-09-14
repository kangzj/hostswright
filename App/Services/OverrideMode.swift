import Foundation

/// How active groups reach the rest of the system.
enum OverrideMode: Hashable, CaseIterable {
    /// Hostswright writes the groups into /etc/hosts, which most apps honour.
    case hostsFile
    /// The hosts file is still written, and Hostswright also becomes the Mac's DNS resolver.
    case localDNS

    var title: String {
        switch self {
        case .hostsFile: "Hosts File"
        case .localDNS: "Local DNS"
        }
    }

    var symbolName: String {
        switch self {
        case .hostsFile: "doc.text"
        case .localDNS: "antenna.radiowaves.left.and.right"
        }
    }

    var summary: String {
        switch self {
        case .hostsFile: "Active groups are written into /etc/hosts. Most apps and command line tools follow it."
        case .localDNS: "Hostswright also answers this Mac's DNS queries, so every app sees the overrides, and repeat lookups come from a local cache."
        }
    }
}

extension LocalDNSController {
    var mode: OverrideMode {
        get { isEnabled ? .localDNS : .hostsFile }
        set { setEnabled(newValue == .localDNS) }
    }
}
