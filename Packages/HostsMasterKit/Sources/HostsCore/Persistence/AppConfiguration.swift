import Foundation

public struct AppConfiguration: Codable, Equatable, Sendable {
    public var groups: [HostsGroup]

    public init(groups: [HostsGroup] = []) {
        self.groups = groups
    }

    public static let `default` = AppConfiguration()

    public var enabledGroups: [HostsGroup] { groups.filter(\.isEnabled) }

    public var managedSection: String? { ManagedSection.render(groups) }

    public func group(id: UUID) -> HostsGroup? {
        groups.first { $0.id == id }
    }

    public mutating func update(id: UUID, _ change: (inout HostsGroup) -> Void) {
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return }
        change(&groups[index])
    }

    public mutating func remove(id: UUID) {
        groups.removeAll { $0.id == id }
    }

    public func uniqueName(basedOn base: String) -> String {
        let taken = Set(groups.map(\.name))
        guard taken.contains(base) else { return base }
        var suffix = 2
        while taken.contains("\(base) \(suffix)") { suffix += 1 }
        return "\(base) \(suffix)"
    }

    private enum CodingKeys: String, CodingKey {
        case groups
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        groups = try container.decodeIfPresent([HostsGroup].self, forKey: .groups) ?? []
    }
}
