import Foundation

enum SidebarSelection: Hashable {
    case group(UUID)
    case hostsFile
    case localDNS
    case queryLog
}
