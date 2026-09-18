import Domain
import SwiftUI

/// Distribuição de tokens entre os modelos que mais pesaram na janela.
struct ModelBreakdownView: View {
    let models: [ModelUsage]
    /// Participação de cada modelo na janela, entre 0 e 1.
    let share: (ModelUsage) -> Double

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("MODELOS PRINCIPAIS")
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(.secondary)

            ForEach(models) { model in
                row(model)
            }
        }
    }

    private func row(_ model: ModelUsage) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            HStack(spacing: Theme.Spacing.xs) {
                Text(model.shortName)
                    .font(Theme.Typography.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: Theme.Spacing.xs)
                Text(Formatters.tokenCount(model.tokens.input))
                    .font(Theme.Typography.number(Theme.Typography.caption))
                    .foregroundStyle(.secondary)
            }

            MeterBar(
                fraction: share(model),
                height: Theme.Metrics.thinMeterHeight,
                label: "Participação de \(model.shortName)",
                valueText: Formatters.percent(share(model))
            )
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Modelos") {
    let window = PreviewData.todayWindow
    return ModelBreakdownView(models: window.rankedModels) { window.share(of: $0) }
        .padding(Theme.Metrics.cardPadding)
        .frame(width: Theme.Metrics.panelWidth)
}
