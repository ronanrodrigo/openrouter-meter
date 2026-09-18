import SwiftUI

/// Tokens visuais do aplicativo.
///
/// Nenhuma tela declara cor, fonte ou medida literal: tudo vem daqui e é sempre um
/// recurso do sistema (material, cor semântica, tipografia dinâmica). Espaçamentos e
/// raios seguem a grade de 4pt.
enum Theme {
    /// Espaçamentos, em múltiplos de 4pt.
    enum Spacing {
        static var hairline: CGFloat {
            2
        }

        static var xxs: CGFloat {
            4
        }

        static var xs: CGFloat {
            8
        }

        static var sm: CGFloat {
            12
        }

        static var md: CGFloat {
            16
        }

        static var lg: CGFloat {
            24
        }
    }

    /// Raios de canto.
    enum Radius {
        static var small: CGFloat {
            8
        }

        static var medium: CGFloat {
            10
        }
    }

    /// Medidas fixas do painel da barra de menus e da janela de ajustes.
    enum Metrics {
        static var panelWidth: CGFloat {
            320
        }

        static var panelPadding: CGFloat {
            16
        }

        static var cardPadding: CGFloat {
            12
        }

        static var meterHeight: CGFloat {
            6
        }

        static var thinMeterHeight: CGFloat {
            4
        }

        static var settingsWidth: CGFloat {
            380
        }
    }

    /// Tipografia do sistema. Números usam `Theme.number(_:)` para não deslocar o layout.
    enum Typography {
        static var sectionTitle: Font {
            .caption
        }

        static var bigNumber: Font {
            .title3.weight(.semibold)
        }

        static var metric: Font {
            .headline
        }

        static var body: Font {
            .subheadline
        }

        static var caption: Font {
            .caption
        }

        /// Mesma fonte, com dígitos monoespaçados.
        static func number(_ base: Font) -> Font {
            base.monospacedDigit()
        }
    }

    /// Preenchimentos derivados de cores semânticas — funcionam em claro e em escuro.
    enum Palette {
        static var surface: Color {
            Color.secondary.opacity(0.08)
        }

        static var track: Color {
            Color.secondary.opacity(0.16)
        }

        static var border: Color {
            Color.secondary.opacity(0.14)
        }
    }

    /// Formas padrão.
    enum Shapes {
        static func card(_ radius: CGFloat = Theme.Radius.medium) -> RoundedRectangle {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
        }
    }
}
