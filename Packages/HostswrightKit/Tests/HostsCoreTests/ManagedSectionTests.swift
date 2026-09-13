import HostsCore
import Testing

@Suite struct ManagedSectionTests {
    let stock = """
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

    @Test func rendersOnlyEnabledGroupsInOrder() {
        let groups = [
            HostsGroup(name: "Off", content: "1.1.1.1 off", isEnabled: false),
            HostsGroup(name: "Dev", content: "\n10.0.0.1 dev.local\n\n", isEnabled: true),
            HostsGroup(name: "Tube", content: "127.0.0.1 a.tube\n127.0.0.1 b.tube", isEnabled: true),
        ]
        #expect(ManagedSection.render(groups) == "# Group: Dev\n10.0.0.1 dev.local\n\n# Group: Tube\n127.0.0.1 a.tube\n127.0.0.1 b.tube")
    }

    @Test func rendersNilWhenNothingEnabled() {
        #expect(ManagedSection.render([HostsGroup(name: "Off", content: "1.1.1.1 x")]) == nil)
        #expect(ManagedSection.render([]) == nil)
    }

    @Test func dropsLinesThatLookLikeMarkers() {
        let group = HostsGroup(name: "Evil", content: "1.1.1.1 a\n\(ManagedSection.endMarker)\n2.2.2.2 b", isEnabled: true)
        #expect(ManagedSection.render([group]) == "# Group: Evil\n1.1.1.1 a\n2.2.2.2 b")
    }

    @Test func insertsSectionAtEndOfFile() {
        let file = HostsFile(parsing: stock).replacingManaged(with: "# Group: Dev\n10.0.0.1 dev.local")
        let expected = stock.trimmingCharacters(in: .newlines) + "\n\n" + ManagedSection.startMarker + "\n# Group: Dev\n10.0.0.1 dev.local\n" + ManagedSection.endMarker + "\n"
        #expect(file.rendered() == expected)
    }

    @Test func replacesExistingSectionAndPreservesSurroundings() {
        let original = stock + "\n" + ManagedSection.startMarker + "\nold\n" + ManagedSection.endMarker + "\n\n1.2.3.4 trailing\n"
        let parsed = HostsFile(parsing: original)
        #expect(parsed.managed == "old")
        #expect(parsed.after.contains("1.2.3.4 trailing"))
        let updated = parsed.replacingManaged(with: "new").rendered()
        #expect(updated.contains(ManagedSection.startMarker + "\nnew\n" + ManagedSection.endMarker + "\n\n1.2.3.4 trailing\n"))
        #expect(!updated.contains("old"))
        #expect(updated.hasPrefix("##\n# Host Database"))
    }

    @Test func removingSectionLeavesCleanFile() {
        let original = stock + "\n" + ManagedSection.startMarker + "\nx\n" + ManagedSection.endMarker + "\n"
        #expect(HostsFile(parsing: original).replacingManaged(with: nil).rendered() == stock)
    }

    @Test func roundTripIsStable() {
        let original = stock + "\n" + ManagedSection.startMarker + "\n# Group: A\n1.1.1.1 a\n" + ManagedSection.endMarker + "\n"
        let once = HostsFile(parsing: original).rendered()
        #expect(once == original)
        #expect(HostsFile(parsing: once).rendered() == once)
    }

    @Test func repairsMissingEndMarker() {
        let damaged = stock + "\n" + ManagedSection.startMarker + "\nstale\nmore\n"
        let repaired = HostsFile(parsing: damaged).replacingManaged(with: "fresh").rendered()
        #expect(repaired == stock + "\n" + ManagedSection.startMarker + "\nfresh\n" + ManagedSection.endMarker + "\n")
    }

    @Test func customLinesIgnoreStockEntriesRegardlessOfWhitespace() {
        let file = HostsFile(parsing: stock + "\n# --- SWITCHHOSTS_CONTENT_START ---\n\n10.0.0.5 staging.example.com\n")
        #expect(file.customLines == ["# --- SWITCHHOSTS_CONTENT_START ---", "10.0.0.5 staging.example.com"])
    }

    @Test func removingCustomLinesMatchesExactly() {
        let file = HostsFile(parsing: stock + "\n1.1.1.1 keep\n2.2.2.2 drop\n")
        let cleaned = file.removingCustomLines(["2.2.2.2 drop"]).rendered()
        #expect(cleaned.contains("1.1.1.1 keep"))
        #expect(!cleaned.contains("2.2.2.2 drop"))
    }
}
