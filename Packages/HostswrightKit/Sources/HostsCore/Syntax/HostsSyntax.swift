import Foundation

public enum HostsSyntax {
    public static func parse(_ text: String) -> [HostsLine] {
        text.split(separator: "\n", omittingEmptySubsequences: false).map { parseLine(String($0)) }
    }

    public static func issues(in text: String) -> [HostsIssue] {
        parse(text).enumerated().compactMap { index, line in
            guard case .invalid(let reason) = line else { return nil }
            return HostsIssue(lineNumber: index + 1, reason: reason)
        }
    }

    public static func parseLine(_ rawLine: String) -> HostsLine {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        if line.isEmpty { return .blank }
        if line.hasPrefix("#") { return .comment(String(line.dropFirst()).trimmingCharacters(in: .whitespaces)) }

        var comment: String?
        var body = Substring(line)
        if let hash = body.firstIndex(of: "#") {
            comment = body[body.index(after: hash)...].trimmingCharacters(in: .whitespaces)
            body = body[..<hash]
        }

        let fields = body.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let address = fields.first else { return .invalid(reason: "Missing address") }
        guard isValidAddress(address) else { return .invalid(reason: "\"\(address)\" is not an IPv4 or IPv6 address") }
        let hostnames = Array(fields.dropFirst())
        guard !hostnames.isEmpty else { return .invalid(reason: "No hostname after \(address)") }
        if let bad = hostnames.first(where: { !isValidHostname($0) }) {
            return .invalid(reason: "\"\(bad)\" is not a valid hostname")
        }
        return .entry(HostsEntry(address: address, hostnames: hostnames, comment: comment))
    }

    public static func isValidAddress(_ text: String) -> Bool {
        var v4 = in_addr()
        var v6 = in6_addr()
        return inet_pton(AF_INET, text, &v4) == 1 || inet_pton(AF_INET6, text, &v6) == 1
    }

    static func isValidHostname(_ text: String) -> Bool {
        guard !text.isEmpty, text.count <= 253 else { return false }
        return text.unicodeScalars.allSatisfy { scalar in
            scalar.properties.isAlphabetic || scalar.properties.numericType != nil || scalar == "-" || scalar == "." || scalar == "_"
        }
    }
}
