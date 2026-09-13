import Foundation

/// A hosts file split around Hostswright's managed section so that section can be replaced without touching anything else.
public struct HostsFile: Equatable, Sendable {
    public static let path = "/etc/hosts"

    static let stockFile = """
    ##
    # Host Database
    #
    # localhost is used to configure the loopback interface
    # when the system is booting.  Do not change this entry.
    ##
    127.0.0.1\tlocalhost
    255.255.255.255\tbroadcasthost
    ::1             localhost
    """

    public var before: [String]
    public var managed: String?
    public var after: [String]

    public init(before: [String], managed: String?, after: [String]) {
        self.before = before
        self.managed = managed
        self.after = after
    }

    public init(parsing text: String) {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let start = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == ManagedSection.startMarker }) else {
            self.init(before: lines, managed: nil, after: [])
            return
        }
        let end = lines[(start + 1)...].firstIndex { $0.trimmingCharacters(in: .whitespaces) == ManagedSection.endMarker }
        let inner = lines[(start + 1)..<(end ?? lines.endIndex)]
        self.init(
            before: Array(lines[..<start]),
            managed: ManagedSection.trimmingBlankEdges(Array(inner)).joined(separator: "\n"),
            after: end.map { Array(lines[($0 + 1)...]) } ?? []
        )
    }

    public func rendered() -> String {
        var lines = ManagedSection.trimmingBlankEdges(before)
        if let managed {
            if !lines.isEmpty { lines.append("") }
            lines.append(ManagedSection.startMarker)
            lines.append(contentsOf: managed.split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
            lines.append(ManagedSection.endMarker)
        }
        let trailing = ManagedSection.trimmingBlankEdges(after)
        if !trailing.isEmpty {
            lines.append("")
            lines.append(contentsOf: trailing)
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public func replacingManaged(with section: String?) -> HostsFile {
        HostsFile(before: before, managed: section, after: after)
    }

    /// Lines outside the managed section that did not ship with macOS, such as entries left behind by another hosts tool.
    public var customLines: [String] {
        (before + after)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !Self.isStockLine($0) }
    }

    public static func isStockLine(_ line: String) -> Bool {
        stockLines.contains(collapsingWhitespace(line))
    }

    private static let stockLines = Set(stockFile.split(separator: "\n").map { collapsingWhitespace(String($0)) })

    private static func collapsingWhitespace(_ line: String) -> String {
        line.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    public func removingCustomLines(_ lines: [String]) -> HostsFile {
        let doomed = Set(lines.map { $0.trimmingCharacters(in: .whitespaces) })
        func keep(_ line: String) -> Bool { !doomed.contains(line.trimmingCharacters(in: .whitespaces)) }
        return HostsFile(before: before.filter(keep), managed: managed, after: after.filter(keep))
    }
}
