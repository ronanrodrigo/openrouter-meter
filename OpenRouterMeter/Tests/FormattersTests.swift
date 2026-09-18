import Domain
import Foundation
@testable import OpenRouterMeter
import Testing

/// Espaço fixo (U+00A0) que o formatador de moeda do sistema coloca entre `US$` e o número.
private let nbsp = "\u{00A0}"

/// Valores de amostra dos testes de formatação e de estado.
enum TestFixtures {
    static let capturedAt = UnixTimestamp(seconds: 1_700_000_000)

    static var account: AccountSnapshot {
        AccountSnapshot(
            totalCredits: Money(dollars: 221.90),
            totalUsage: Money(dollars: 130.00),
            dailyUsage: Money(dollars: 12.34),
            weeklyUsage: Money(dollars: 48.10),
            monthlyUsage: Money(dollars: 118.40),
            isFreeTier: false,
            freeModelQuota: FreeModelQuota(used: 621, limit: 1000)
        )
    }

    static var todayWindow: UsageWindow {
        UsageWindow(
            kind: .today,
            tokens: TokenCounts(input: 1_240_500, output: 318_400, cacheRead: 96000, cacheWrite: 4200),
            calls: 42,
            cost: Money(dollars: 12.34),
            models: [sonnet, gpt]
        )
    }

    private static var sonnet: ModelUsage {
        ModelUsage(
            model: "anthropic/claude-sonnet-4.5",
            calls: 21,
            tokens: TokenCounts(input: 720_000, output: 180_000),
            estimatedCost: Money(dollars: 7.10)
        )
    }

    private static var gpt: ModelUsage {
        ModelUsage(
            model: "openai/gpt-5.2",
            calls: 13,
            tokens: TokenCounts(input: 380_500, output: 96400),
            estimatedCost: Money(dollars: 3.55)
        )
    }

    static var report: UsageReport {
        UsageReport(
            account: account,
            windows: [todayWindow],
            source: .accountActivity,
            capturedAt: capturedAt
        )
    }
}

struct FormattersTests {
    private let ptBR = Locale(identifier: "pt_BR")
    private let enUS = Locale(identifier: "en_US")

    // MARK: - Dinheiro

    @Test("Dinheiro em pt-BR segue o padrão brasileiro para o dólar")
    func moneyInPortugueseUsesDollarPrefix() {
        #expect(Formatters.money(Money(dollars: 91.90), locale: ptBR) == "US$\(nbsp)91,90")
        #expect(Formatters.money(Money(dollars: 45.98), locale: ptBR) == "US$\(nbsp)45,98")
    }

    @Test("Dinheiro respeita o locale informado")
    func moneyHonoursLocale() {
        #expect(Formatters.money(Money(dollars: 91.90), locale: enUS) == "$91.90")
    }

    @Test("Formato padrão do aplicativo é o brasileiro")
    func moneyDefaultsToBrazilianStandard() {
        #expect(Formatters.money(Money(dollars: 91.90)) == "US$\(nbsp)91,90")
        #expect(Formatters.money(.zero) == "US$\(nbsp)0,00")
    }

    @Test("Saldo negativo aparece com sinal")
    func moneyNegative() {
        #expect(Formatters.money(Money(dollars: -5), locale: ptBR) == "-US$\(nbsp)5,00")
    }

    // MARK: - Tokens

    @Test("Tokens em milhões usam o sufixo mi")
    func tokenCountMillions() {
        #expect(Formatters.tokenCount(62_700_000, locale: ptBR) == "62,7 mi")
        #expect(Formatters.tokenCount(1_000_000, locale: ptBR) == "1 mi")
    }

    @Test("Tokens em milhares usam o sufixo mil")
    func tokenCountThousands() {
        #expect(Formatters.tokenCount(459_000, locale: ptBR) == "459 mil")
        #expect(Formatters.tokenCount(1500, locale: ptBR) == "1,5 mil")
    }

    @Test("Abaixo de mil o número aparece inteiro")
    func tokenCountUnits() {
        #expect(Formatters.tokenCount(847, locale: ptBR) == "847")
        #expect(Formatters.tokenCount(0, locale: ptBR) == "0")
    }

    @Test("Número inteiro usa separador de milhar do locale")
    func integerUsesGrouping() {
        #expect(Formatters.integer(312, locale: ptBR) == "312")
        #expect(Formatters.integer(12400, locale: ptBR) == "12.400")
    }

    @Test("Fração vira porcentagem inteira e limitada a 100%")
    func percentIsClamped() {
        #expect(Formatters.percent(0, locale: ptBR) == "0%")
        #expect(Formatters.percent(0.587, locale: ptBR) == "59%")
        #expect(Formatters.percent(1, locale: ptBR) == "100%")
        #expect(Formatters.percent(1.4, locale: ptBR) == "100%")
    }

    // MARK: - Tempo relativo

    @Test("Menos de um minuto é agora")
    func relativeTimeJustNow() {
        #expect(Formatters.relativeTime(secondsAgo: 0) == "agora")
        #expect(Formatters.relativeTime(secondsAgo: 59) == "agora")
    }

    @Test("Minutos, horas e dias em pt-BR")
    func relativeTimeUnits() {
        #expect(Formatters.relativeTime(secondsAgo: 240) == "há 4 min")
        #expect(Formatters.relativeTime(secondsAgo: 3600) == "há 1 h")
        #expect(Formatters.relativeTime(secondsAgo: 3 * 3600 + 120) == "há 3 h")
        #expect(Formatters.relativeTime(secondsAgo: 2 * 86400) == "há 2 dias")
    }

    @Test("Instante futuro não vira tempo negativo")
    func relativeTimeForFutureInstant() {
        #expect(Formatters
            .relativeTime(from: TestFixtures.capturedAt, to: Date(timeIntervalSince1970: 1_699_999_000)) == "agora")
    }

    // MARK: - Título da barra

    @Test("Título da barra segue o modo escolhido")
    func menuBarTitlePerMode() {
        #expect(Formatters
            .menuBarTitle(for: .remainingBalance, report: TestFixtures.report, locale: ptBR) == "US$\(nbsp)91,90")
        #expect(Formatters
            .menuBarTitle(for: .todayCost, report: TestFixtures.report, locale: ptBR) == "US$\(nbsp)12,34")
    }

    @Test("Sem relatório a barra mostra um traço")
    func menuBarTitleWithoutReport() {
        #expect(Formatters.menuBarTitle(for: .remainingBalance, report: nil, locale: ptBR) == "—")
    }
}
