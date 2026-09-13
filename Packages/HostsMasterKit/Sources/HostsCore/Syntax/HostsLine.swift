import Foundation

public enum HostsLine: Equatable, Sendable {
    case blank
    case comment(String)
    case entry(HostsEntry)
    case invalid(reason: String)

    public var isEntry: Bool {
        if case .entry = self { return true }
        return false
    }
}

public struct HostsEntry: Equatable, Sendable {
    public var address: String
    public var hostnames: [String]
    public var comment: String?

    public init(address: String, hostnames: [String], comment: String? = nil) {
        self.address = address
        self.hostnames = hostnames
        self.comment = comment
    }
}

public struct HostsIssue: Equatable, Sendable, Identifiable {
    public var lineNumber: Int
    public var reason: String

    public var id: Int { lineNumber }
}
