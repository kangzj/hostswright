import ServiceManagement
import SwiftUI

struct HelperSettingsTab: View {
    @Environment(AppModel.self) private var model
    @State private var helperVersion: Int?

    var body: some View {
        Form {
            Section {
                LabeledContent("Status") {
                    Label(model.helper.status.summary, systemImage: model.helper.isEnabled ? "checkmark.circle.fill" : "circle.dashed")
                        .foregroundStyle(model.helper.isEnabled ? .green : .secondary)
                }
                if let helperVersion {
                    LabeledContent("Protocol version", value: "\(helperVersion)")
                }
                if let error = model.helperInstallError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
            Section {
                if model.helper.status == .unsignedBuild {
                    Text(model.helper.status.callToAction ?? "")
                        .font(.callout)
                    Link("How to build a copy that can edit hosts", destination: HelperClient.Status.signingGuideURL)
                } else {
                    HStack {
                        Button(model.helper.isEnabled ? "Reinstall" : "Set Up") { model.installHelper() }
                        if model.helper.status == .requiresApproval {
                            Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
                        }
                        if model.helper.status != .notRegistered {
                            Button("Remove", role: .destructive) { Task { await model.removeHelper() } }
                        }
                        Spacer()
                        Button("Refresh") { model.refreshHelperStatus() }
                    }
                }
                Text("Hostswright installs a small root helper that is the only component allowed to write /etc/hosts. It only ever rewrites the section between Hostswright's own markers and flushes the DNS cache afterwards.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task(id: model.helper.status) {
            helperVersion = model.helper.isEnabled ? try? await model.helper.version() : nil
        }
    }
}
