import DNSCore
import SwiftUI

struct QueryLogView: View {
    @Environment(AppModel.self) private var model
    @State private var filter = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Query Log")
                        .font(.title2.weight(.semibold))
                    Text("The most recent lookups Local DNS answered and where each answer came from.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                TextField("Filter", text: $filter, prompt: Text("Filter by name"))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }
            legend
            if entries.isEmpty {
                emptyState
            } else {
                Table(entries) {
                    TableColumn("Time") { entry in
                        Text(entry.time, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute().second())
                            .monospacedDigit()
                    }
                    .width(80)
                    TableColumn("Type") { entry in Text(entry.type) }
                        .width(64)
                    TableColumn("Name") { entry in Text(entry.name).font(.body.monospaced()) }
                    TableColumn("Answered by") { entry in
                        Text(entry.outcome.summary)
                            .foregroundStyle(entry.outcome.tint)
                    }
                    .width(min: 110, ideal: 150)
                    TableColumn("Took") { entry in
                        Text("\(entry.durationMilliseconds) ms")
                            .monospacedDigit()
                    }
                    .width(72)
                }
            }
        }
        .padding(20)
        .onAppear { model.dns.pageAppeared() }
        .onDisappear { model.dns.pageDisappeared() }
    }

    private var entries: [QueryLogEntry] {
        let all = model.dns.status.log.reversed()
        guard !filter.isEmpty else { return Array(all) }
        return all.filter { $0.name.localizedCaseInsensitiveContains(filter) }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem("hosts", "Answered from your groups", .green)
            legendItem("cache", "Answered from the cache", .blue)
            legendItem("→ server", "Forwarded upstream", .secondary)
            legendItem("failed", "No server answered", .red)
        }
        .font(.caption)
    }

    private func legendItem(_ label: String, _ meaning: String, _ tint: Color) -> some View {
        HStack(spacing: 4) {
            Text(label).foregroundStyle(tint).fontWeight(.medium)
            Text(meaning).foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(emptyMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyMessage: String {
        if !model.dns.isEnabled { return "Switch to Local DNS mode to see lookups here." }
        if !model.dns.settings.keepsQueryLog { return "Logging is turned off on the Local DNS page." }
        return filter.isEmpty ? "No lookups yet." : "No lookups match \"\(filter)\"."
    }
}
