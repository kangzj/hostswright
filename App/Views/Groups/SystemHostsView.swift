import SwiftUI

struct SystemHostsView: View {
    @Environment(AppModel.self) private var model
    @Binding var selection: SidebarSelection?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("System")
                        .font(.title2.weight(.semibold))
                    Text("Everything in /etc/hosts outside Hostswright's section. These lines are never changed.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !model.hostsFile.customLines.isEmpty {
                    ImportButton(selection: $selection)
                }
            }
            ScrollView {
                Text(systemText)
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

    private var systemText: String {
        (model.hostsFile.file.before + model.hostsFile.file.after).joined(separator: "\n")
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
