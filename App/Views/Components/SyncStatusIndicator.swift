import SwiftUI

struct SyncStatusIndicator: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let state = model.sync.state
        HStack(spacing: 5) {
            if state == .pending || state == .applying {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Image(systemName: model.helper.isEnabled ? state.symbolName : "circle.dashed")
                    .foregroundStyle(model.helper.isEnabled ? state.tint : .secondary)
            }
            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .help(state.summary)
    }

    private var summary: String {
        guard model.helper.isEnabled else { return "Not set up" }
        let mode = model.dns.mode.title
        return model.sync.state == .synced ? "\(mode) · in sync" : model.sync.state.shortSummary
    }
}

extension HostsSync.State {
    var shortSummary: String {
        switch self {
        case .synced: "In sync"
        case .pending, .applying: "Applying…"
        case .outOfSync: "Out of sync"
        case .failed: "Failed"
        }
    }
}
