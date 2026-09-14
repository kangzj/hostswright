import AppKit
import SwiftUI

struct MainWindow: View {
    static let id = "hostswright.main"

    @Environment(AppModel.self) private var model
    @State private var selection: SidebarSelection?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var window: NSWindow?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            GroupSidebar(selection: $selection)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
                .toolbar(removing: .sidebarToggle)
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
                ToolbarItem(placement: .navigation) {
                    Button {
                        toggleSidebar()
                    } label: {
                        Label("Toggle Sidebar", systemImage: "sidebar.leading")
                    }
                    .keyboardShortcut("s", modifiers: [.control, .command])
                }
                ToolbarItem(placement: .primaryAction) {
                    ModePicker()
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 720, minHeight: 460)
        .background(WindowAccessor { window = $0 })
        .onChange(of: model.configuration.groups.map(\.id), initial: true) { _, ids in
            if case .group(let id) = selection, !ids.contains(id) { selection = nil }
            if selection == nil, let first = ids.first { selection = .group(first) }
        }
    }

    // The system toggle animates the split, and on macOS 26 the columns snap mid-animation, so the switch is instant.
    // Without the animation SwiftUI grows the window by the sidebar's width instead of shrinking the detail; put it back.
    private func toggleSidebar() {
        let frame = window?.frame
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
        }
        guard let window, let frame else { return }
        DispatchQueue.main.async {
            if window.frame != frame { window.setFrame(frame, display: true) }
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

private struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { if let window = view.window { onWindow(window) } }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window { onWindow(window) }
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
