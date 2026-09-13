import Foundation

/// Splits lines adopted from a foreign hosts tool into groups, one per block separated by blank lines.
public enum ImportedGroups {
    static let foreignMarkerPrefixes = ["# --- SWITCHHOSTS", "# ---SWITCHHOSTS"]

    public static func groups(from file: HostsFile) -> [HostsGroup] {
        let blocks = (file.before + file.after)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !isForeignMarker($0) }
            .split(whereSeparator: \.isEmpty)
            .map(Array.init)
            .filter { block in block.contains { !HostsFile.isStockLine($0) && !$0.hasPrefix("#") } }

        var usedNames: Set<String> = []
        return blocks.enumerated().map { index, block in
            let body = block.filter { !HostsFile.isStockLine($0) }
            var name = suggestedName(for: body) ?? "Imported \(index + 1)"
            var suffix = 2
            while !usedNames.insert(name).inserted {
                name = "\(suggestedName(for: body) ?? "Imported") \(suffix)"
                suffix += 1
            }
            return HostsGroup(name: name, content: body.joined(separator: "\n"), isEnabled: true)
        }
    }

    private static func isForeignMarker(_ line: String) -> Bool {
        foreignMarkerPrefixes.contains { line.uppercased().hasPrefix($0.uppercased()) }
    }

    private static func suggestedName(for block: [String]) -> String? {
        if let comment = block.first, comment.hasPrefix("#"), !block.dropFirst().isEmpty {
            let title = comment.drop { $0 == "#" || $0 == " " }
            if !title.isEmpty, !title.contains(where: { $0 == "." }) { return String(title) }
        }
        guard let firstEntry = block.compactMap({ line -> HostsEntry? in
            if case .entry(let entry) = HostsSyntax.parseLine(line) { return entry }
            return nil
        }).first, let host = firstEntry.hostnames.first else { return nil }
        return commonDomain(in: block) ?? host
    }

    private static func commonDomain(in block: [String]) -> String? {
        let hosts = block.compactMap { line -> String? in
            if case .entry(let entry) = HostsSyntax.parseLine(line) { return entry.hostnames.first }
            return nil
        }
        guard hosts.count > 1 else { return nil }
        let suffixes = hosts.map { Array($0.split(separator: ".").reversed()) }
        guard let shortest = suffixes.min(by: { $0.count < $1.count }) else { return nil }
        var common: [Substring] = []
        for (index, label) in shortest.enumerated() where suffixes.allSatisfy({ $0[index] == label }) {
            common.append(label)
        }
        guard common.count >= 2 else { return nil }
        return common.reversed().joined(separator: ".")
    }
}
