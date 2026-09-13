import HostsCore
import SwiftUI

struct GroupSidebar: View {
    @Environment(AppModel.self) private var model
    @Binding var selection: SidebarSelection?
    @State private var pendingDeletion: UUID?

    var body: some View {
        List(selection: $selection) {
            Section("Groups") {
                ForEach(model.configuration.groups) { group in
                    GroupRow(group: group)
                        .tag(SidebarSelection.group(group.id))
                        .contextMenu {
                            Button(group.isEnabled ? "Turn Off" : "Turn On") { model.setEnabled(!group.isEnabled, id: group.id) }
                            Button("Delete…", role: .destructive) { pendingDeletion = group.id }
                        }
                }
                .onMove { model.moveGroups(from: $0, to: $1) }
            }
            Section {
                Label("System", systemImage: "lock")
                    .tag(SidebarSelection.system)
                LocalDNSSidebarRow()
                    .tag(SidebarSelection.localDNS)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Button {
                        selection = .group(model.addGroup())
                    } label: {
                        Label("New Group", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                    Spacer()
                    SyncStatusIndicator()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(.bar)
        }
        .onDeleteCommand {
            if case .group(let id) = selection { pendingDeletion = id }
        }
        .confirmationDialog(
            "Delete \"\(pendingDeletionName)\"?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let id = pendingDeletion { model.deleteGroup(id: id) }
            }
        } message: {
            Text("Its entries are removed from /etc/hosts right away. This cannot be undone.")
        }
    }

    private var pendingDeletionName: String {
        pendingDeletion.flatMap { model.configuration.group(id: $0)?.name } ?? ""
    }
}

private struct GroupRow: View {
    @Environment(AppModel.self) private var model
    let group: HostsGroup

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(get: { group.isEnabled }, set: { model.setEnabled($0, id: group.id) }))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            VStack(alignment: .leading, spacing: 1) {
                Text(group.name.isEmpty ? "Untitled" : group.name)
                    .lineLimit(1)
                Text(Formatters.entries(group.entryCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
