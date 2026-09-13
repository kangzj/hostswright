import Foundation

final class HelperListener: NSObject, NSXPCListenerDelegate {
    private let service: HelperService
    private let requirement: String

    init(service: HelperService) {
        self.service = service
        requirement = Self.clientRequirement()
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.setCodeSigningRequirement(requirement)
        connection.exportedInterface = NSXPCInterface(with: HostsMasterHelperProtocol.self)
        connection.exportedObject = service
        connection.resume()
        return true
    }

    // A team-signed build pins clients to the same team; an ad-hoc development build can only match the identifier.
    private static func clientRequirement() -> String {
        let identifier = #"identifier "\#(appBundleIdentifier)""#
        guard let team = CodeSigningInfo.teamIdentifier() else { return identifier }
        return #"anchor apple generic and \#(identifier) and certificate leaf[subject.OU] = "\#(team)""#
    }
}
