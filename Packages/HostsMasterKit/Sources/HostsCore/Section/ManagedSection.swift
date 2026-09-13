import Foundation

public enum ManagedSection {
    public static let startMarker = "# ==== HostsMaster: managed section, edits here are overwritten ===="
    public static let endMarker = "# ==== HostsMaster: end of managed section ===="
    static let groupHeaderPrefix = "# Group: "

    public static func render(_ groups: [HostsGroup]) -> String? {
        let enabled = groups.filter(\.isEnabled)
        guard !enabled.isEmpty else { return nil }
        return enabled.map(renderGroup).joined(separator: "\n\n")
    }

    private static func renderGroup(_ group: HostsGroup) -> String {
        let body = group.content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0 != startMarker && $0 != endMarker }
        let header = groupHeaderPrefix + group.name.trimmingCharacters(in: .whitespaces)
        return ([header] + trimmingBlankEdges(body)).joined(separator: "\n")
    }

    static func trimmingBlankEdges(_ lines: [String]) -> [String] {
        var lines = lines[...]
        while lines.first?.isEmpty == true { lines.removeFirst() }
        while lines.last?.isEmpty == true { lines.removeLast() }
        return Array(lines)
    }
}
