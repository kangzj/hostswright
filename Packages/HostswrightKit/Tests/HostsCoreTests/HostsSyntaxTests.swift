import HostsCore
import Testing

@Suite struct HostsSyntaxTests {
    @Test func parsesEntriesCommentsAndBlanks() {
        let lines = HostsSyntax.parse("127.0.0.1 localhost dev.local # loop\n\n# note\n::1\tlocalhost")
        #expect(lines == [
            .entry(HostsEntry(address: "127.0.0.1", hostnames: ["localhost", "dev.local"], comment: "loop")),
            .blank,
            .comment("note"),
            .entry(HostsEntry(address: "::1", hostnames: ["localhost"])),
        ])
    }

    @Test func reportsInvalidLinesWithNumbers() {
        let issues = HostsSyntax.issues(in: "127.0.0.1 ok\n999.1.1.1 bad\n127.0.0.1\n127.0.0.1 bad host!")
        #expect(issues.map(\.lineNumber) == [2, 3, 4])
        #expect(issues[0].reason.contains("999.1.1.1"))
        #expect(issues[1].reason.contains("No hostname"))
        #expect(issues[2].reason.contains("host!"))
    }

    @Test func acceptsIPv6AndUnderscoreHostnames() {
        #expect(HostsSyntax.parseLine("fe80::1 router").isEntry)
        #expect(HostsSyntax.parseLine("10.0.0.1 my_host.example").isEntry)
    }

    @Test func countsEntriesPerGroup() {
        let group = HostsGroup(name: "g", content: "# c\n1.1.1.1 a\n\n2.2.2.2 b c\nbad")
        #expect(group.entryCount == 2)
    }
}
