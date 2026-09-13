import SwiftUI

struct MenuBarLabel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Image(systemName: model.hasActiveGroups ? "point.3.filled.connected.trianglepath.dotted" : "point.3.connected.trianglepath.dotted")
            .accessibilityLabel("Hostswright")
    }
}
