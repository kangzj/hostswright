import HostsCore
import Testing

@Suite struct ImportedGroupsTests {
    let switchHosts = """
    ##
    # Host Database
    #
    # localhost is used to configure the loopback interface
    # when the system is booting.  Do not change this entry.
    ##
    127.0.0.1\tlocalhost
    255.255.255.255\tbroadcasthost
    ::1             localhost

    # --- SWITCHHOSTS_CONTENT_START ---

    10.0.0.5 staging.example.com
    #10.0.0.5 www.example.com

    127.0.0.1 me.tunnel.example.net
    127.0.0.1 me-lab.tunnel.example.net

    # Lab Boxes
    127.0.0.1 atlas.lab.example.org
    127.0.0.1 nova.lab.example.org
    """

    @Test func splitsBlocksAndNamesThem() {
        let groups = ImportedGroups.groups(from: HostsFile(parsing: switchHosts))
        #expect(groups.map(\.name) == ["staging.example.com", "tunnel.example.net", "Lab Boxes"])
        #expect(groups.allSatisfy { $0.isEnabled })
        #expect(groups[0].content == "10.0.0.5 staging.example.com\n#10.0.0.5 www.example.com")
        #expect(groups[2].content == "# Lab Boxes\n127.0.0.1 atlas.lab.example.org\n127.0.0.1 nova.lab.example.org")
    }

    @Test func stockFileImportsNothing() {
        let stockOnly = switchHosts.components(separatedBy: "# --- SWITCHHOSTS")[0]
        #expect(ImportedGroups.groups(from: HostsFile(parsing: stockOnly)).isEmpty)
        #expect(HostsFile(parsing: stockOnly).customLines.isEmpty)
    }

    @Test func duplicateNamesGetSuffixes() {
        let file = HostsFile(parsing: "1.1.1.1 a.example.com\n\n2.2.2.2 a.example.com\n")
        #expect(ImportedGroups.groups(from: file).map(\.name) == ["a.example.com", "a.example.com 2"])
    }
}
