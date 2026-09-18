import SwiftUI

/// Barra de medição fina, no espírito do medidor de armazenamento do Finder.
struct MeterBar: View {
    /// Tom do preenchimento.
    enum Tone {
        /// Cor de destaque do sistema — para proporções que não indicam risco.
        case accent
        /// Colore por estado: atenção a partir de 75% e crítico a partir de 90%.
        case state
    }

    /// Fração preenchida, entre 0 e 1.
    let fraction: Double
    var height: CGFloat = Theme.Metrics.meterHeight
    var tone: Tone = .accent
    /// Rótulo de acessibilidade do medidor.
    let label: String
    /// Valor de acessibilidade do medidor, já formatado.
    let valueText: String

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Theme.Palette.track)
                Capsule(style: .continuous)
                    .fill(fill)
                    .frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(valueText)
    }

    private var progress: Double {
        min(1, max(0, fraction))
    }

    private var fill: Color {
        guard tone == .state else { return Color.accentColor }
        if progress >= 0.9 {
            return Color.red
        }
        if progress >= 0.75 {
            return Color.orange
        }
        return Color.accentColor
    }
}

#Preview("Medidor") {
    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
        MeterBar(fraction: 0.32, tone: .state, label: "Consumo", valueText: "32%")
        MeterBar(fraction: 0.78, tone: .state, label: "Consumo", valueText: "78%")
        MeterBar(fraction: 0.94, tone: .state, label: "Consumo", valueText: "94%")
        MeterBar(fraction: 0.5, height: Theme.Metrics.thinMeterHeight, label: "Participação", valueText: "50%")
            .frame(width: 180)
    }
    .padding(Theme.Spacing.md)
    .frame(width: Theme.Metrics.panelWidth)
}
