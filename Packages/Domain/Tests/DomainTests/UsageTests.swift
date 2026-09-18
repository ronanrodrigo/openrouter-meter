@testable import Domain
import Testing

@Suite("Tokens e modelos")
struct UsageTests {
    @Test("TokenCounts soma faturável e total")
    func tokenCounts() {
        let counts = TokenCounts(input: 100, output: 50, cacheRead: 10, cacheWrite: 5, reasoning: 7)
        #expect(counts.billed == 150)
        #expect(counts.total == 165)
        #expect(TokenCounts.zero.total == 0)
    }

    @Test("TokenCounts tem padrão zerado")
    func tokenCountsDefaults() {
        #expect(TokenCounts(input: 3).output == 0)
        #expect(TokenCounts(input: 3).billed == 3)
    }

    @Test("ModelUsage encurta o identificador")
    func modelShortName() {
        let usage = ModelUsage(
            model: "deepseek/deepseek-v4.1-flash",
            calls: 12,
            tokens: TokenCounts(input: 10),
            estimatedCost: Money(dollars: 0.02)
        )
        #expect(usage.shortName == "deepseek-v4.1-flash")
        #expect(usage.id == usage.model)
    }

    @Test("ModelUsage sem barra mantém o nome inteiro")
    func modelShortNameWithoutSlash() {
        let usage = ModelUsage(model: "local", calls: 1, tokens: .zero, estimatedCost: .zero)
        #expect(usage.shortName == "local")
    }

    @Test("UsageWindow ordena modelos e calcula participação")
    func windowRankingAndShare() {
        let small = ModelUsage(model: "v/a", calls: 1, tokens: TokenCounts(input: 25), estimatedCost: .zero)
        let big = ModelUsage(model: "v/b", calls: 2, tokens: TokenCounts(input: 75), estimatedCost: .zero)
        let window = UsageWindow(
            kind: .today,
            tokens: TokenCounts(input: 100),
            calls: 3,
            cost: Money(dollars: 1),
            models: [small, big]
        )

        #expect(window.id == .today)
        #expect(window.rankedModels.map(\.model) == ["v/b", "v/a"])
        #expect(window.share(of: big) == 0.75)
        #expect(window.share(of: small) == 0.25)
    }

    @Test("participação é zero quando não há tokens")
    func windowShareWithoutTokens() {
        let model = ModelUsage(model: "v/a", calls: 1, tokens: .zero, estimatedCost: .zero)
        let window = UsageWindow(kind: .lastSevenDays, tokens: .zero, calls: 0, cost: .zero, models: [model])
        #expect(window.share(of: model) == 0)
    }

    @Test("janelas são identificáveis pelos casos")
    func windowKinds() {
        #expect(UsageWindowKind.allCases.count == 2)
        #expect(UsageWindowKind.lastSevenDays.id == "lastSevenDays")
        #expect(UsageSource.accountActivity.rawValue == "accountActivity")
        #expect(UsageSource.localHermes.rawValue == "localHermes")
    }
}
