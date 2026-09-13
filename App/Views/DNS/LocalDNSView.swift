import DNSCore
import SwiftUI

struct LocalDNSView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var dns = model.dns
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let error = dns.lastError {
                    errorRow(error)
                }
                DNSStatusCard()
                DNSUpstreamSection(settings: $dns.settings)
                DNSCacheSection(settings: $dns.settings)
                DNSRulesSection(rules: $dns.settings.rules)
                DNSQueryLogSection(keepsLog: $dns.settings.keepsQueryLog)
            }
            .padding(20)
        }
        .onAppear { model.dns.pageAppeared() }
        .onDisappear { model.dns.pageDisappeared() }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Local DNS")
                    .font(.title2.weight(.semibold))
                Text("Serve your hosts entries as real DNS answers, cache everything else, and forward the rest to the network's resolvers. Apps that bypass the hosts file, Safari included, then see the same overrides.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("On", isOn: Binding(get: { model.dns.isEnabled }, set: { model.dns.setEnabled($0) }))
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(!model.helper.isEnabled)
                .help(model.helper.isEnabled ? "Route this Mac's DNS through Hostswright." : "Finish setting up Hostswright first.")
        }
    }

    private func errorRow(_ error: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            Text(error).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
            Button("Dismiss") { model.dns.clearError() }.controlSize(.small)
        }
        .padding(12)
        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct DNSStatusCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let status = model.dns.status
        SectionCard(title: "Status") {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow {
                    Text("Resolver").foregroundStyle(.secondary)
                    Label(status.isRunning ? "Listening on 127.0.0.1:53" : (status.listenError ?? "Off"),
                          systemImage: status.isRunning ? "checkmark.circle.fill" : "circle.dashed")
                        .foregroundStyle(status.isRunning ? .green : (status.listenError == nil ? .secondary : .red))
                }
                GridRow {
                    Text("Upstream").foregroundStyle(.secondary)
                    Text(status.upstreams.isEmpty ? "None found" : status.upstreams.map(Formatters.server).joined(separator: ", "))
                }
                GridRow {
                    Text("Cache").foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Text(Formatters.cacheSummary(status))
                        Button("Clear Cache") { model.dns.clearCache() }
                            .controlSize(.small)
                            .disabled(!status.isRunning)
                    }
                }
            }
            .font(.callout)
        }
    }
}

private struct DNSUpstreamSection: View {
    @Binding var settings: DNSSettings
    @State private var customText = ""

    var body: some View {
        SectionCard(title: "Upstream servers") {
            Picker("Upstream", selection: Binding(
                get: { isCustom },
                set: { custom in settings.upstream = custom ? .custom(parsedCustom) : .automatic }
            )) {
                Text("From the network").tag(false)
                Text("Custom").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 320)
            if isCustom {
                TextField("1.1.1.1, 8.8.8.8", text: $customText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { settings.upstream = .custom(parsedCustom) }
                    .onChange(of: customText) { _, _ in settings.upstream = .custom(parsedCustom) }
                if let invalid = parsedCustom.first(where: { ServerAddress($0) == nil }) {
                    Text("\"\(invalid)\" is not an IP address.").font(.caption).foregroundStyle(.orange)
                } else {
                    Text("Comma-separated IPv4 or IPv6 addresses, tried in order. Add :port for a non-standard port.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("Uses the DNS servers your network hands out, and follows them when you change networks.")
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
        SectionCard(title: "Cache") {
            HStack(spacing: 24) {
                TTLField(title: "Keep answers at least", seconds: $settings.minimumTTL)
                TTLField(title: "and at most", seconds: $settings.maximumTTL)
            }
            Text("Upstream answers are cached within these bounds; hosts entries always answer with a 5 second lifetime. The cache clears whenever the hosts file changes.")
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
        HStack(spacing: 6) {
            Text(title)
            TextField("", value: Binding(get: { Int(seconds) }, set: { seconds = UInt32(max(0, min($0, 86_400))) }), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
                .multilineTextAlignment(.trailing)
            Text("s").foregroundStyle(.secondary)
        }
        .font(.callout)
    }
}

private struct DNSRulesSection: View {
    @Binding var rules: [ForwardingRule]

    var body: some View {
        SectionCard(title: "Forwarding rules") {
            if rules.isEmpty {
                Text("Send a domain and its subdomains to specific servers, for example a VPN's internal DNS. Everything else goes upstream.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach($rules) { $rule in
                HStack(spacing: 8) {
                    TextField("internal.example", text: $rule.domain)
                        .textFieldStyle(.roundedBorder)
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    TextField("10.0.0.1, 10.0.0.2", text: Binding(
                        get: { rule.servers.joined(separator: ", ") },
                        set: { rule.servers = $0.split(whereSeparator: { $0 == "," || $0.isWhitespace }).map(String.init) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    Button {
                        rules.removeAll { $0.id == rule.id }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                }
                .font(.system(.body, design: .monospaced))
            }
            Button {
                rules.append(ForwardingRule(domain: "", servers: []))
            } label: {
                Label("Add Rule", systemImage: "plus")
            }
            .controlSize(.small)
        }
    }
}

private struct DNSQueryLogSection: View {
    @Environment(AppModel.self) private var model
    @Binding var keepsLog: Bool

    var body: some View {
        SectionCard(title: "Recent queries") {
            Toggle("Keep a log of recent queries", isOn: $keepsLog)
            if keepsLog {
                let entries = model.dns.status.log.suffix(50).reversed()
                if entries.isEmpty {
                    Text(model.dns.status.isRunning ? "No queries yet." : "Turn Local DNS on to see queries here.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(entries)) { entry in
                            QueryLogRow(entry: entry)
                            Divider()
                        }
                    }
                    .font(.system(.callout, design: .monospaced))
                }
            }
        }
    }
}

private struct QueryLogRow: View {
    let entry: QueryLogEntry

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.time, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute().second())
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Text(entry.type)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            Text(entry.name)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(entry.outcome.summary)
                .foregroundStyle(entry.outcome.tint)
                .lineLimit(1)
            Text("\(entry.durationMilliseconds) ms")
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
