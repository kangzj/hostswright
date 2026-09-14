import HostsCore
import SwiftUI

struct GroupSidebar: View {
    @Environment(AppModel.self) private var model
    @Binding var selection: SidebarSelection?
    @State private var pendingDeletion: UUID?

    var body: some View {
        VStack(spacing: 0) {
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
                Section("Resolver") {
                    ResolverRow(title: "Hosts File", symbolName: OverrideMode.hostsFile.symbolName, subtitle: hostsFileSubtitle, isActive: model.helper.isEnabled)
                        .tag(SidebarSelection.hostsFile)
                    ResolverRow(title: "Local DNS", symbolName: OverrideMode.localDNS.symbolName, subtitle: localDNSSubtitle, isActive: model.dns.isEnabled)
                        .tag(SidebarSelection.localDNS)
                    ResolverRow(title: "Query Log", symbolName: "list.bullet.rectangle", subtitle: queryLogSubtitle, isActive: model.dns.isEnabled)
                        .tag(SidebarSelection.queryLog)
                }
            }
            .listStyle(.sidebar)
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

    private var hostsFileSubtitle: String {
        guard model.helper.isEnabled else { return "Not set up" }
        let count = model.configuration.enabledGroups.count
        let groups = count == 1 ? "1 group applied" : "\(count) groups applied"
        return model.sync.state == .synced ? groups : model.sync.state.shortSummary
    }

    private var localDNSSubtitle: String {
        guard model.dns.isEnabled else { return "Off" }
        return model.dns.status.isRunning ? "Resolving for this Mac" : (model.dns.status.listenError == nil ? "Starting…" : "Could not start")
    }

    private var queryLogSubtitle: String {
        guard model.dns.isEnabled else { return "Needs Local DNS" }
        let count = model.dns.status.queries
        return count == 1 ? "1 query" : "\(count) queries"
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

private struct ResolverRow: View {
    let title: String
    let symbolName: String
    let subtitle: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.title3)
                .frame(width: 24)
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
