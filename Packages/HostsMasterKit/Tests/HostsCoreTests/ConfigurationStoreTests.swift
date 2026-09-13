import Foundation
import HostsCore
import Testing

@Suite struct ConfigurationStoreTests {
    func tempDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    @Test func loadsDefaultWhenMissing() {
        let store = ConfigurationStore(directory: tempDirectory())
        #expect(!store.exists)
        #expect(store.load() == .default)
    }

    @Test func roundTrips() throws {
        let store = ConfigurationStore(directory: tempDirectory())
        let config = AppConfiguration(groups: [
            HostsGroup(name: "Dev", content: "10.0.0.1 dev.local", isEnabled: true),
            HostsGroup(name: "Off", content: "", isEnabled: false),
        ])
        try store.save(config)
        #expect(store.exists)
        #expect(store.load() == config)
    }

    @Test func toleratesCorruptAndPartialFiles() throws {
        let directory = tempDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("configuration.json")
        try "not json".write(to: file, atomically: true, encoding: .utf8)
        #expect(ConfigurationStore(directory: directory).load() == .default)
        try "{}".write(to: file, atomically: true, encoding: .utf8)
        #expect(ConfigurationStore(directory: directory).load() == .default)
    }

    @Test func uniqueNamesAndMutations() {
        var config = AppConfiguration(groups: [HostsGroup(name: "New Group")])
        #expect(config.uniqueName(basedOn: "New Group") == "New Group 2")
        #expect(config.uniqueName(basedOn: "Other") == "Other")
        let id = config.groups[0].id
        config.update(id: id) { $0.isEnabled = true }
        #expect(config.enabledGroups.count == 1)
        #expect(config.managedSection == "# Group: New Group")
        config.remove(id: id)
        #expect(config.groups.isEmpty)
        #expect(config.managedSection == nil)
    }
}
