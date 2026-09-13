import Testing
@testable import DNSCore

@Suite struct DNSNameTests {
    @Test func parsesAndLowercasesWithTrailingDot() {
        let name = DNSName("Example.COM.")
        #expect(name?.labels == ["example", "com"])
        #expect(name?.description == "example.com")
    }

    @Test func rejectsEmptyAndMalformedNames() {
        #expect(DNSName("") == nil)
        #expect(DNSName("a..b") == nil)
        #expect(DNSName(".example.com") == nil)
        #expect(DNSName(String(repeating: "a", count: 64) + ".com") == nil)
        #expect(DNSName(String(repeating: "a", count: 63) + ".com") != nil)
    }

    @Test func rootNameIsAllowed() {
        let root = DNSName(".")
        #expect(root?.labels == [])
        #expect(root?.description == ".")
    }

    @Test func memberwiseInitLowercases() {
        #expect(DNSName(labels: ["WWW", "Example"]).labels == ["www", "example"])
    }

    @Test func suffixMatching() throws {
        let parent = try #require(DNSName("example.com"))
        #expect(try #require(DNSName("example.com")).hasSuffix(parent))
        #expect(try #require(DNSName("a.b.example.com")).hasSuffix(parent))
        #expect(!(try #require(DNSName("notexample.com")).hasSuffix(parent)))
        #expect(!(try #require(DNSName("com")).hasSuffix(parent)))
        #expect(try #require(DNSName("anything.org")).hasSuffix(try #require(DNSName("."))))
    }
}
