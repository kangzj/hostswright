import Foundation

enum SidebarSelection: Hashable {
    case group(UUID)
    case system
    case localDNS
}
