public struct DNSName: Hashable, Sendable, CustomStringConvertible {
    public static let maximumLabelLength = 63
    public static let maximumLabelCount = 127
    public static let maximumTextLength = 253

    public let labels: [String]

    public init(labels: [String]) {
        self.labels = labels.map { $0.lowercased() }
    }

    public init?(_ text: String) {
        guard !text.isEmpty, text.utf8.count <= Self.maximumTextLength + 1 else { return nil }
        let body = text.hasSuffix(".") ? text.dropLast() : Substring(text)
        if body.isEmpty {
            guard text == "." else { return nil }
            self.init(labels: [])
            return
        }
        let labels = body.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard labels.count <= Self.maximumLabelCount,
              labels.allSatisfy({ !$0.isEmpty && $0.utf8.count <= Self.maximumLabelLength })
        else { return nil }
        self.init(labels: labels)
    }

    public var description: String {
        labels.isEmpty ? "." : labels.joined(separator: ".")
    }

    public func hasSuffix(_ other: DNSName) -> Bool {
        labels.count >= other.labels.count && labels.suffix(other.labels.count).elementsEqual(other.labels)
    }
}
