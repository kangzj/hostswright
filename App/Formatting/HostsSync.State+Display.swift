import SwiftUI

extension HostsSync.State {
    var summary: String {
        switch self {
        case .synced: "Hosts file is up to date"
        case .pending, .applying: "Applying…"
        case .outOfSync: "Hosts file differs from your groups"
        case .failed(let message): message
        }
    }

    var symbolName: String {
        switch self {
        case .synced: "checkmark.circle.fill"
        case .pending, .applying: "arrow.triangle.2.circlepath"
        case .outOfSync: "exclamationmark.triangle.fill"
        case .failed: "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .synced: .green
        case .pending, .applying: .secondary
        case .outOfSync: .orange
        case .failed: .red
        }
    }
}
