import SwiftUI

/// Rodapé do painel: quando o relatório foi lido e as ações do aplicativo.
struct StatusFooterView: View {
    let lastRefresh: Date?
    let isRefreshing: Bool
    let onRefresh: () -> Void
    let onSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(statusText)
                .font(Theme.Typography.number(Theme.Typography.caption))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Última atualização")
                .accessibilityValue(statusText)

            Spacer(minLength: Theme.Spacing.xs)

            iconButton("Atualizar", systemImage: "arrow.clockwise", action: onRefresh)
                .disabled(isRefreshing)

            iconButton("Ajustes…", systemImage: "gearshape", action: onSettings)

            iconButton("Sair", systemImage: "power", action: onQuit)
        }
        .buttonStyle(.borderless)
    }

    private var statusText: String {
        guard let lastRefresh else { return "Nunca atualizado" }
        return "Atualizado " + Formatters.relativeTime(since: lastRefresh)
    }

    private func iconButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 22, height: 22)
        }
        .help(title)
        .accessibilityLabel(title)
    }
}

#Preview("Rodapé") {
    VStack(spacing: Theme.Spacing.md) {
        StatusFooterView(
            lastRefresh: Date().addingTimeInterval(-240),
            isRefreshing: false,
            onRefresh: {},
            onSettings: {},
            onQuit: {}
        )
        StatusFooterView(
            lastRefresh: nil,
            isRefreshing: true,
            onRefresh: {},
            onSettings: {},
            onQuit: {}
        )
    }
    .padding(Theme.Metrics.panelPadding)
    .frame(width: Theme.Metrics.panelWidth)
}
