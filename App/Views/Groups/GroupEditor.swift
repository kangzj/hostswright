import HostsCore
import SwiftUI

struct GroupEditor: View {
    @Environment(AppModel.self) private var model
    let id: UUID

    var body: some View {
        if let group = model.configuration.group(id: id) {
            editor(for: group)
        }
    }

    private func editor(for group: HostsGroup) -> some View {
        let issues = HostsSyntax.issues(in: group.content)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                TextField("Group name", text: binding(\.name))
                    .textFieldStyle(.plain)
                    .font(.title2.weight(.semibold))
                Toggle("Active", isOn: binding(\.isEnabled))
                    .toggleStyle(.switch)
            }
            HostsTextEditor(text: binding(\.content))
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.quaternary))
                .overlay(alignment: .topLeading) {
                    if group.content.isEmpty {
                        Text("127.0.0.1 dev.example.com")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 46)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
            footer(for: group, issues: issues)
        }
        .padding(20)
    }

    private func footer(for group: HostsGroup, issues: [HostsIssue]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(Formatters.entries(group.entryCount))
                if !issues.isEmpty {
                    Label(Formatters.issues(issues.count), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                Spacer()
                Text(group.isEnabled ? "Applied to /etc/hosts" : "Not applied")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            ForEach(issues.prefix(5)) { issue in
                Text("Line \(issue.lineNumber): \(issue.reason)")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<HostsGroup, Value>) -> Binding<Value> {
        Binding(
            get: { model.configuration.group(id: id)![keyPath: keyPath] },
            set: { value in model.configuration.update(id: id) { $0[keyPath: keyPath] = value } }
        )
    }
}
