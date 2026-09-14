import SwiftUI

struct MainWindow: View {
    static let id = "hostswright.main"

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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    ModePicker()
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 720, minHeight: 460)
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
        case .hostsFile:
            HostsFileView(selection: $selection)
        case .localDNS:
            LocalDNSView()
        case .queryLog:
            QueryLogView()
        case nil:
            EmptyStateView(selection: $selection)
        }
    }
}

/// The one control that decides how overrides reach the system; mirrored in the menu bar.
struct ModePicker: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var dns = model.dns
        Picker("Mode", selection: $dns.mode) {
            ForEach(OverrideMode.allCases, id: \.self) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .disabled(!model.helper.isEnabled)
        .help(model.dns.mode.summary)
    }
}
