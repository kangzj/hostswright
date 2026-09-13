import SwiftUI

struct LocalDNSSidebarRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(get: { model.dns.isEnabled }, set: { model.dns.setEnabled($0) }))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .disabled(!model.helper.isEnabled)
            VStack(alignment: .leading, spacing: 1) {
                Text("Local DNS")
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        guard model.dns.isEnabled else { return "Off" }
        return model.dns.status.isRunning ? "Serving 127.0.0.1" : "Starting…"
    }
}
