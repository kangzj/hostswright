import SwiftUI

struct MainWindow: View {
    static let id = "hostsmaster.main"

    @Environment(AppModel.self) private var model
    @State private var selection: SidebarSelection?

    var body: some View {
        NavigationSplitView {
            GroupSidebar(selection: $selection)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } detail: {
            VStack(spacing: 0) {
                StatusBanner()
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                detail
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 680, minHeight: 420)
        .onChange(of: model.configuration.groups.map(\.id), initial: true) { _, ids in
            if case .group(let id) = selection, !ids.contains(id) { selection = nil }
            if selection == nil, let first = ids.first { selection = .group(first) }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .group(let id):
            GroupEditor(id: id)
        case .system:
            SystemHostsView(selection: $selection)
        case nil:
            EmptyStateView(selection: $selection)
        }
    }
}
