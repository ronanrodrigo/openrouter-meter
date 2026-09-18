import Domain
import Foundation

/// Formatação de dinheiro, tokens e tempo para a interface.
///
/// Textos de interface são pt-BR (idioma do produto), e os números seguem o mesmo padrão
/// de forma **explícita** — não o idioma da máquina. Derivar do `Locale.current` fazia o
/// mesmo saldo aparecer como `US$ 91,90` para quem usa o sistema em português e `$ 91.90`
/// para quem usa em inglês, e ainda tornava o resultado dependente do ambiente.
enum Formatters {
    /// Locale de exibição do aplicativo.
    static let displayLocale = Locale(identifier: "pt_BR")

    // MARK: - Dinheiro

    /// Valor monetário no padrão do sistema, com a moeda fixada em dólar.
    static func money(_ amount: Money, locale: Locale = Formatters.displayLocale) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount.dollars)) ?? "—"
    }

    // MARK: - Contagens

    /// Número inteiro com separador de milhar do sistema.
    static func integer(_ value: Int, locale: Locale = Formatters.displayLocale) -> String {
        decimal(Double(value), fractionDigits: 0, locale: locale)
    }

    /// Contagem compacta de tokens: `62,7 mi`, `459 mil`, `847`.
    static func tokenCount(_ count: Int, locale: Locale = Formatters.displayLocale) -> String {
        let value = Double(count)
        if value >= 999_950 {
            return decimal(value / 1_000_000, fractionDigits: 1, locale: locale) + " mi"
        }
        if value >= 1000 {
            return decimal(value / 1000, fractionDigits: 1, locale: locale) + " mil"
        }
        return decimal(value, fractionDigits: 0, locale: locale)
    }

    /// Fração como porcentagem inteira: `59%`.
    static func percent(_ fraction: Double, locale: Locale = Formatters.displayLocale) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.locale = locale
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: min(1, max(0, fraction)))) ?? "—"
    }

    private static func decimal(_ value: Double, fractionDigits: Int, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }

    // MARK: - Tempo

    /// Hora relativa em pt-BR: `agora`, `há 4 min`, `há 3 h`, `há 2 dias`.
    static func relativeTime(from instant: UnixTimestamp, to reference: Date = Date()) -> String {
        relativeTime(secondsAgo: reference.timeIntervalSince1970 - instant.seconds)
    }

    /// Hora relativa a partir de um `Date`.
    static func relativeTime(since date: Date, now reference: Date = Date()) -> String {
        relativeTime(from: UnixTimestamp(seconds: date.timeIntervalSince1970), to: reference)
    }

    /// Hora relativa a partir de uma quantidade de segundos já decorridos.
    static func relativeTime(secondsAgo delta: Double) -> String {
        guard delta >= 60 else { return "agora" }

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = displayLocale

        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar
        formatter.unitsStyle = .short
        formatter.maximumUnitCount = 1
        if delta < 3600 {
            formatter.allowedUnits = [.minute]
        } else if delta < 86400 {
            formatter.allowedUnits = [.hour]
        } else {
            formatter.allowedUnits = [.day]
        }

        guard let quantity = formatter.string(from: delta), !quantity.isEmpty else { return "agora" }
        return "há " + quantity
    }

    // MARK: - Barra de menus

    /// Título exibido na barra de menus, conforme o modo escolhido pelo usuário.
    static func menuBarTitle(
        for mode: MenuBarDisplayMode,
        report: UsageReport?,
        locale: Locale = Formatters.displayLocale
    ) -> String {
        guard let report else { return "—" }
        switch mode {
        case .remainingBalance:
            return money(report.account.remaining, locale: locale)
        case .todayCost:
            return money(report.account.dailyUsage, locale: locale)
        }
    }
}
