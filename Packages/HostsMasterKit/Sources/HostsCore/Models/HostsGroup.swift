import Foundation

public struct HostsGroup: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var content: String
    public var isEnabled: Bool

    public init(id: UUID = UUID(), name: String, content: String = "", isEnabled: Bool = false) {
        self.id = id
        self.name = name
        self.content = content
        self.isEnabled = isEnabled
    }

    public var entryCount: Int {
        HostsSyntax.parse(content).filter(\.isEntry).count
    }
}
