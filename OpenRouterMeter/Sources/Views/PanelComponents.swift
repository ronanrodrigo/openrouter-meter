import SwiftUI

/// Cabeçalho discreto do painel: nome do aplicativo e origem dos dados.
struct PanelHeaderView: View {
    let title: String
    let source: String?
    let isRefreshing: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "gauge.medium")
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(title)
                .font(Theme.Typography.body.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: Theme.Spacing.xs)

            if isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Atualizando")
            } else if let source {
                Text(source)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityLabel("Origem dos dados")
                    .accessibilityValue(source)
            }
        }
    }
}

/// Aviso em linha, com uma ação opcional — usado para falhas.
struct NoticeView: View {
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                Image(systemName: "exclamationmark.triangle")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text(message)
                    .font(Theme.Typography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(actionTitle, action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Estado de carregamento do painel.
struct LoadingView: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ProgressView()
                .controlSize(.small)
            Text("Lendo o consumo…")
                .font(Theme.Typography.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Cabeçalho") {
    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
        PanelHeaderView(title: "OpenRouter Meter", source: "Atividade da conta", isRefreshing: false)
        PanelHeaderView(title: "OpenRouter Meter", source: nil, isRefreshing: true)
        NoticeView(message: OpenRouterMeterPreviewMessages.unauthorized, actionTitle: "Abrir Ajustes", action: {})
        LoadingView()
    }
    .padding(Theme.Metrics.panelPadding)
    .frame(width: Theme.Metrics.panelWidth)
}

enum OpenRouterMeterPreviewMessages {
    static let unauthorized = "A chave da OpenRouter foi recusada. Confira a chave em Ajustes."
}
