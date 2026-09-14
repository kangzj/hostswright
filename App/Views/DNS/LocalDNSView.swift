import DNSCore
import SwiftUI

struct LocalDNSView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var dns = model.dns
        Form {
            Section {
                modeRow
                if let error = dns.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
            if dns.isEnabled {
                statusSection
            }
            DNSUpstreamSection(settings: $dns.settings)
            DNSCacheSection(settings: $dns.settings)
            DNSRulesSection(rules: $dns.settings.rules)
            Section {
                Toggle("Keep a log of recent queries", isOn: $dns.settings.keepsQueryLog)
                Text("The Query Log page shows the last 200 lookups and where each answer came from.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { model.dns.pageAppeared() }
        .onDisappear { model.dns.pageDisappeared() }
    }

    private var modeRow: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: OverrideMode.localDNS.symbolName)
                .font(.title)
                .foregroundStyle(model.dns.isEnabled ? Color.accentColor : .secondary)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.dns.isEnabled ? "Local DNS is on" : "Local DNS is off")
                    .font(.headline)
                Text("Hosts File mode writes your groups into /etc/hosts, which most apps follow. Local DNS mode does that too and also makes Hostswright this Mac's DNS resolver: every app, Safari included, gets the same overrides, and repeat lookups are answered from a local cache.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Local DNS", isOn: Binding(get: { model.dns.isEnabled }, set: { model.dns.setEnabled($0) }))
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(!model.helper.isEnabled)
                .help(model.helper.isEnabled ? "Route this Mac's DNS through Hostswright." : "Finish setting up Hostswright first.")
        }
        .padding(.vertical, 4)
    }

    private var statusSection: some View {
        let status = model.dns.status
        return Section("Status") {
            LabeledContent("Resolver") {
                Label(status.isRunning ? "Listening on 127.0.0.1:53" : (status.listenError ?? "Starting…"),
                      systemImage: status.isRunning ? "checkmark.circle.fill" : (status.listenError == nil ? "circle.dashed" : "xmark.octagon.fill"))
                    .foregroundStyle(status.isRunning ? .green : (status.listenError == nil ? .secondary : .red))
            }
            LabeledContent("Upstream", value: status.upstreams.isEmpty ? "None found" : status.upstreams.map(Formatters.server).joined(separator: ", "))
            LabeledContent("Cache") {
                HStack(spacing: 12) {
                    Text(Formatters.cacheSummary(status))
                    Button("Clear") { model.dns.clearCache() }
                        .controlSize(.small)
                        .disabled(!status.isRunning)
                }
            }
        }
    }
}

private struct DNSUpstreamSection: View {
    @Binding var settings: DNSSettings
    @State private var customText = ""

    var body: some View {
        Section("Upstream servers") {
            Picker("Forward to", selection: Binding(
                get: { isCustom },
                set: { custom in settings.upstream = custom ? .custom(parsedCustom) : .automatic }
            )) {
                Text("The network's DNS servers").tag(false)
                Text("Custom servers").tag(true)
            }
            if isCustom {
                TextField("Servers", text: $customText, prompt: Text("1.1.1.1, 8.8.8.8"))
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: customText) { _, _ in settings.upstream = .custom(parsedCustom) }
                if let invalid = parsedCustom.first(where: { ServerAddress($0) == nil }) {
                    Text("\"\(invalid)\" is not an IP address.").font(.caption).foregroundStyle(.orange)
                } else {
                    Text("Comma-separated, tried in order. Add :port for a non-standard port.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("Follows the servers your network hands out, even when you switch networks.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if case .custom(let servers) = settings.upstream { customText = servers.joined(separator: ", ") }
        }
    }

    private var isCustom: Bool {
        if case .custom = settings.upstream { return true }
        return false
    }

    private var parsedCustom: [String] {
        customText.split(whereSeparator: { $0 == "," || $0.isWhitespace }).map(String.init)
    }
}

private struct DNSCacheSection: View {
    @Binding var settings: DNSSettings

    var body: some View {
        Section("Cache") {
            TTLField(title: "Keep answers for at least", seconds: $settings.minimumTTL)
            TTLField(title: "and at most", seconds: $settings.maximumTTL)
            Text("Upstream answers stay cached within these bounds. Hosts entries always answer with a 5 second lifetime, and the whole cache clears whenever the hosts file changes.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onChange(of: settings.minimumTTL) { _, minimum in settings.maximumTTL = max(settings.maximumTTL, minimum) }
        .onChange(of: settings.maximumTTL) { _, maximum in settings.minimumTTL = min(settings.minimumTTL, maximum) }
    }
}

private struct TTLField: View {
    let title: String
    @Binding var seconds: UInt32

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                TextField("", value: Binding(get: { Int(seconds) }, set: { seconds = UInt32(max(0, min($0, 86_400))) }), format: .number)
                    .frame(width: 72)
                    .multilineTextAlignment(.trailing)
                Text("seconds").foregroundStyle(.secondary)
            }
        }
    }
}

private struct DNSRulesSection: View {
    @Binding var rules: [ForwardingRule]

    var body: some View {
        Section {
            ForEach($rules) { $rule in
                HStack(spacing: 8) {
                    TextField("Domain", text: $rule.domain, prompt: Text("internal.example"))
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    TextField("Servers", text: Binding(
                        get: { rule.servers.joined(separator: ", ") },
                        set: { rule.servers = $0.split(whereSeparator: { $0 == "," || $0.isWhitespace }).map(String.init) }
                    ), prompt: Text("10.0.0.1, 10.0.0.2"))
                    Button {
                        rules.removeAll { $0.id == rule.id }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove this rule")
                }
                .font(.system(.body, design: .monospaced))
            }
            Button {
                rules.append(ForwardingRule(domain: "", servers: []))
            } label: {
                Label("Add Rule", systemImage: "plus")
            }
        } header: {
            Text("Forwarding rules")
        } footer: {
            Text("A rule sends a domain and all its subdomains to the servers you name, for example a VPN's private DNS. Names that match no rule go upstream.")
        }
    }
}
