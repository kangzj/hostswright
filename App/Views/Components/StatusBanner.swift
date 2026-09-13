import SwiftUI

struct StatusBanner: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let callToAction = model.helper.status.callToAction {
            banner(symbol: "lock.shield", tint: .blue, text: callToAction) {
                Button(model.helper.status.actionTitle) {
                    if model.helper.status == .unsignedBuild {
                        openURL(HelperClient.Status.signingGuideURL)
                    } else {
                        model.installHelper()
                    }
                }
            }
        } else if let error = model.helperInstallError {
            banner(symbol: "exclamationmark.triangle.fill", tint: .red, text: error) {
                Button("Try Again") { model.installHelper() }
            }
        } else if let error = model.lastActionError {
            banner(symbol: "exclamationmark.triangle.fill", tint: .red, text: error) {
                Button("Dismiss") { model.clearActionError() }
            }
        } else if case .failed(let message) = model.sync.state {
            banner(symbol: "xmark.octagon.fill", tint: .red, text: "Could not update /etc/hosts: \(message)") {
                Button("Try Again") { model.sync.reapply() }
            }
        } else if model.sync.state == .outOfSync {
            banner(symbol: "exclamationmark.triangle.fill", tint: .orange, text: "The hosts file was changed outside Hostswright and no longer matches your groups.") {
                Button("Re-apply") { model.sync.reapply() }
            }
        }
    }

    private func banner<Action: View>(symbol: String, tint: Color, text: String, @ViewBuilder action: () -> Action) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .font(.title3)
            Text(text)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
            action()
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(tint.opacity(0.3)))
    }
}
