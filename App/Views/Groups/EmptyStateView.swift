import SwiftUI

struct EmptyStateView: View {
    @Environment(AppModel.self) private var model
    @Binding var selection: SidebarSelection?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No hosts groups yet")
                .font(.title3.weight(.semibold))
            Text("A group is a few lines of hosts entries you can switch on and off from the menu bar.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            HStack {
                Button("New Group") { selection = .group(model.addGroup()) }
                    .keyboardShortcut(.defaultAction)
                if !model.hostsFile.customLines.isEmpty {
                    ImportButton(selection: $selection)
                }
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}
