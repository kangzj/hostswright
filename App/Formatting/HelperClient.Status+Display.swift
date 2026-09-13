import Foundation

extension HelperClient.Status {
    static let signingGuideURL = URL(string: "https://github.com/kangzj/hostsmaster#building-a-copy-that-can-edit-hosts")!

    var summary: String {
        switch self {
        case .unsignedBuild: "Unavailable in this unsigned build"
        case .notRegistered: "Not set up"
        case .requiresApproval: "Waiting for approval in Login Items"
        case .enabled: "Ready"
        }
    }

    var callToAction: String? {
        switch self {
        case .unsignedBuild: "This build is not signed with an Apple certificate, so macOS will not run its helper. See the README for a two-minute fix."
        case .notRegistered: "HostsMaster needs a one-time permission to edit /etc/hosts. You will not be asked again."
        case .requiresApproval: "Almost there. Turn on HostsMaster in System Settings › General › Login Items & Extensions."
        case .enabled: nil
        }
    }

    var actionTitle: String {
        switch self {
        case .unsignedBuild: "Open Guide"
        case .notRegistered: "Set Up"
        case .requiresApproval: "Open Login Items"
        case .enabled: ""
        }
    }
}
