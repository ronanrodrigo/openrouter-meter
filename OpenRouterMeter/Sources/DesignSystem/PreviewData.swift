import Domain
import Foundation

/// Valores de amostra determinísticos para os previews das views.
///
/// Nunca tocam a rede: os previews montam as telas com estes dados e, quando precisam do
/// view model, usam `CompositionRoot.sample()`.
enum PreviewData {
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
            tokens: TokenCounts(
                input: 1_240_500,
                output: 318_400,
                cacheRead: 96000,
                cacheWrite: 4200,
                reasoning: 18900
            ),
            calls: 42,
            cost: Money(dollars: 12.34),
            models: [todaySonnet, todayGPT, todayGemini]
        )
    }

    static var weekWindow: UsageWindow {
        UsageWindow(
            kind: .lastSevenDays,
            tokens: TokenCounts(
                input: 9_820_000,
                output: 2_410_000,
                cacheRead: 780_000,
                cacheWrite: 31000,
                reasoning: 142_000
            ),
            calls: 312,
            cost: Money(dollars: 48.10),
            models: [weekSonnet, weekGPT, weekLlama]
        )
    }

    static var report: UsageReport {
        UsageReport(
            account: account,
            windows: [todayWindow, weekWindow],
            source: .accountActivity,
            capturedAt: UnixTimestamp(seconds: Date().timeIntervalSince1970 - 240)
        )
    }

    /// Relatório como o de quem não tem chave: só o histórico local, sem modelos detalhados.
    static var reportWithoutKey: UsageReport {
        UsageReport(
            account: account,
            windows: [],
            source: .localHermes,
            capturedAt: UnixTimestamp(seconds: Date().timeIntervalSince1970 - 3600)
        )
    }

    // MARK: - Modelos de amostra

    private static var todaySonnet: ModelUsage {
        ModelUsage(
            model: "anthropic/claude-sonnet-4.5",
            calls: 21,
            tokens: TokenCounts(input: 720_000, output: 180_000),
            estimatedCost: Money(dollars: 7.10)
        )
    }

    private static var todayGPT: ModelUsage {
        ModelUsage(
            model: "openai/gpt-5.2",
            calls: 13,
            tokens: TokenCounts(input: 380_500, output: 96400),
            estimatedCost: Money(dollars: 3.55)
        )
    }

    private static var todayGemini: ModelUsage {
        ModelUsage(
            model: "google/gemini-3-pro",
            calls: 8,
            tokens: TokenCounts(input: 140_000, output: 42000),
            estimatedCost: Money(dollars: 1.69)
        )
    }

    private static var weekSonnet: ModelUsage {
        ModelUsage(
            model: "anthropic/claude-sonnet-4.5",
            calls: 168,
            tokens: TokenCounts(input: 6_100_000, output: 1_480_000),
            estimatedCost: Money(dollars: 31.40)
        )
    }

    private static var weekGPT: ModelUsage {
        ModelUsage(
            model: "openai/gpt-5.2",
            calls: 92,
            tokens: TokenCounts(input: 2_850_000, output: 700_000),
            estimatedCost: Money(dollars: 12.20)
        )
    }

    private static var weekLlama: ModelUsage {
        ModelUsage(
            model: "meta-llama/llama-4-scout",
            calls: 52,
            tokens: TokenCounts(input: 870_000, output: 230_000),
            estimatedCost: Money(dollars: 4.50)
        )
    }
}
