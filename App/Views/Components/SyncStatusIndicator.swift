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
            Text(shortSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .help(state.summary)
    }

    private var shortSummary: String {
        guard model.helper.isEnabled else { return "Not set up" }
        switch model.sync.state {
        case .synced: return "In sync"
        case .pending, .applying: return "Applying"
        case .outOfSync: return "Out of sync"
        case .failed: return "Failed"
        }
    }
}
