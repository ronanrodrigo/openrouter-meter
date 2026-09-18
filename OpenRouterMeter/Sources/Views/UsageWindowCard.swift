import Domain
import SwiftUI

/// Cartão de uma janela de consumo (hoje ou últimos sete dias).
struct UsageWindowCard: View {
    let window: UsageWindow

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.lg) {
                MetricView(title: "Tokens", value: Formatters.tokenCount(window.tokens.billed))
                MetricView(title: "Chamadas", value: Formatters.integer(window.calls))
                MetricView(title: "Custo", value: Formatters.money(window.cost))
                Spacer(minLength: 0)
            }

            let top = Array(window.rankedModels.prefix(3))
            if !top.isEmpty {
                Divider()
                    .padding(.vertical, Theme.Spacing.xxs)
                ModelBreakdownView(models: top) { model in
                    window.share(of: model)
                }
            }
        }
        .padding(Theme.Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface, in: Theme.Shapes.card())
        .overlay(Theme.Shapes.card().strokeBorder(Theme.Palette.border, lineWidth: 0.5))
    }

    private var title: String {
        switch window.kind {
        case .today: "HOJE"
        case .lastSevenDays: "ÚLTIMOS 7 DIAS"
        }
    }
}

/// Métrica rotulada, com o número em dígitos monoespaçados.
struct MetricView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.hairline) {
            Text(title)
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(.secondary)
            Text(value)
                .font(Theme.Typography.number(Theme.Typography.metric))
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Hoje") {
    UsageWindowCard(window: PreviewData.todayWindow)
        .padding(Theme.Metrics.panelPadding)
        .frame(width: Theme.Metrics.panelWidth)
}

#Preview("Últimos 7 dias") {
    UsageWindowCard(window: PreviewData.weekWindow)
        .padding(Theme.Metrics.panelPadding)
        .frame(width: Theme.Metrics.panelWidth)
}
