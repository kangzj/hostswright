import SwiftUI

struct MenuBarMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if model.helper.isEnabled {
            groupToggles
            Divider()
            modePicker
        } else {
            Button("Set Up Hostswright…") { openMainWindow() }
        }
        Divider()
        Button("Flush DNS Cache") { Task { await model.flushDNSCache() } }
            .disabled(!model.helper.isEnabled)
        Button("Open Hostswright…") { openMainWindow() }
        Button("Settings…") { DockPresence.present { openSettings() } }
            .keyboardShortcut(",")
        Divider()
        Button("Quit Hostswright") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    @ViewBuilder
    private var groupToggles: some View {
        if model.sync.needsAttention {
            Button {
                model.sync.reapply()
            } label: {
                Label("Re-apply Hosts", systemImage: model.sync.state.symbolName)
            }
            Divider()
        }
        if model.configuration.groups.isEmpty {
            Text("No groups yet")
        } else {
            ForEach(model.configuration.groups) { group in
                Toggle(group.name, isOn: Binding(
                    get: { group.isEnabled },
                    set: { model.setEnabled($0, id: group.id) }
                ))
            }
            Divider()
            Button("Turn All Off") { model.disableAll() }
                .disabled(!model.hasActiveGroups)
        }
    }

    private var modePicker: some View {
        @Bindable var dns = model.dns
        return Picker("Mode", selection: $dns.mode) {
            ForEach(OverrideMode.allCases, id: \.self) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.inline)
    }

    private func openMainWindow() {
        DockPresence.present { openWindow(id: MainWindow.id) }
    }
}
