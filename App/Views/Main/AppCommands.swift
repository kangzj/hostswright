import SwiftUI

struct AppCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Group") { model.addGroup() }
                .keyboardShortcut("n")
        }
        CommandMenu("Hosts") {
            Button("Re-apply Hosts") { model.sync.reapply() }
                .keyboardShortcut("r")
                .disabled(!model.helper.isEnabled)
            Button("Flush DNS Cache") { Task { await model.flushDNSCache() } }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(!model.helper.isEnabled)
            Divider()
            Button("Turn All Groups Off") { model.disableAll() }
                .disabled(!model.hasActiveGroups)
        }
    }
}
