import HostsCore
import SwiftUI

/// The live /etc/hosts, with the sync state and the import offer for lines left by other tools.
struct HostsFileView: View {
    @Environment(AppModel.self) private var model
    @Binding var selection: SidebarSelection?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hosts File")
                        .font(.title2.weight(.semibold))
                    Text("Active groups are written between Hostswright's markers in /etc/hosts. Everything outside the markers is left exactly as it is.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !model.hostsFile.customLines.isEmpty {
                    ImportButton(selection: $selection)
                }
            }
            HStack(spacing: 8) {
                SyncStatusIndicator()
                if model.sync.needsAttention {
                    Button("Re-apply") { model.sync.reapply() }
                        .controlSize(.small)
                }
                Spacer()
                Text(HostsFile.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            ScrollView {
                Text(model.hostsFile.file.rendered())
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.quaternary))
        }
        .padding(20)
    }
}

struct ImportButton: View {
    @Environment(AppModel.self) private var model
    @Binding var selection: SidebarSelection?

    var body: some View {
        Button {
            Task {
                if let first = await model.importFromHostsFile().first { selection = .group(first) }
            }
        } label: {
            Label("Import \(Formatters.lines(model.hostsFile.customLines.count))", systemImage: "square.and.arrow.down")
        }
        .disabled(!model.helper.isEnabled)
        .help(model.helper.isEnabled
            ? "Move the custom lines found in /etc/hosts into groups you can switch on and off."
            : "Finish setting up Hostswright to import.")
    }
}
