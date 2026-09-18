import Application
import Domain

/// Consumo fixo com duas janelas e três modelos, para pré-visualizações e testes.
///
/// Determinístico e sem entrada/saída: ignora o instante recebido e devolve sempre os mesmos
/// valores, para que projetos de interface e testes não dependam de rede nem de `state.db`.
public struct SampleUsageGateway: UsageGateway {
    public static let sampleWindows: [UsageWindow] = [
        UsageWindow(
            kind: .today,
            tokens: TokenCounts(input: 184_320, output: 42910, cacheRead: 96400, cacheWrite: 8120, reasoning: 12450),
            calls: 96,
            cost: Money(dollars: 4.82),
            models: [
                ModelUsage(
                    model: "anthropic/claude-sonnet-4.5",
                    calls: 54,
                    tokens: TokenCounts(
                        input: 121_400,
                        output: 28310,
                        cacheRead: 64200,
                        cacheWrite: 5400,
                        reasoning: 8900
                    ),
                    estimatedCost: Money(dollars: 3.21)
                ),
                ModelUsage(
                    model: "openai/gpt-5.1",
                    calls: 27,
                    tokens: TokenCounts(
                        input: 44920,
                        output: 10600,
                        cacheRead: 24100,
                        cacheWrite: 1820,
                        reasoning: 2410
                    ),
                    estimatedCost: Money(dollars: 1.18)
                ),
                ModelUsage(
                    model: "google/gemini-3-pro",
                    calls: 15,
                    tokens: TokenCounts(input: 18000, output: 4000, cacheRead: 8100, cacheWrite: 900, reasoning: 1140),
                    estimatedCost: Money(dollars: 0.43)
                ),
            ]
        ),
        UsageWindow(
            kind: .lastSevenDays,
            tokens: TokenCounts(
                input: 902_140,
                output: 211_380,
                cacheRead: 468_200,
                cacheWrite: 39600,
                reasoning: 61900
            ),
            calls: 512,
            cost: Money(dollars: 21.44),
            models: [
                ModelUsage(
                    model: "anthropic/claude-sonnet-4.5",
                    calls: 288,
                    tokens: TokenCounts(
                        input: 588_300,
                        output: 138_400,
                        cacheRead: 302_500,
                        cacheWrite: 26100,
                        reasoning: 44200
                    ),
                    estimatedCost: Money(dollars: 14.62)
                ),
                ModelUsage(
                    model: "openai/gpt-5.1",
                    calls: 141,
                    tokens: TokenCounts(
                        input: 202_440,
                        output: 48980,
                        cacheRead: 108_000,
                        cacheWrite: 8700,
                        reasoning: 12300
                    ),
                    estimatedCost: Money(dollars: 4.51)
                ),
                ModelUsage(
                    model: "google/gemini-3-pro",
                    calls: 83,
                    tokens: TokenCounts(
                        input: 111_400,
                        output: 24000,
                        cacheRead: 57700,
                        cacheWrite: 4800,
                        reasoning: 5400
                    ),
                    estimatedCost: Money(dollars: 2.31)
                ),
            ]
        ),
    ]

    public init() {}

    public var source: UsageSource {
        .localHermes
    }

    public func windows(now: UnixTimestamp) async throws -> [UsageWindow] {
        Self.sampleWindows
    }
}
