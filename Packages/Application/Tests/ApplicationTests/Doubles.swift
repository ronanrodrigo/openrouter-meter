@testable import Domain
import Testing

/// Dublês determinísticos, sem rede e sem IO.
enum Doubles {
    static func snapshot(credits: Double = 210, usage: Double = 118.1) -> AccountSnapshot {
        AccountSnapshot(totalCredits: Money(dollars: credits), totalUsage: Money(dollars: usage))
    }

    static func window(_ kind: UsageWindowKind, input: Int = 1000) -> UsageWindow {
        UsageWindow(
            kind: kind,
            tokens: TokenCounts(input: input, output: 100),
            calls: 5,
            cost: Money(dollars: 0.5),
            models: [ModelUsage(model: "v/m", calls: 5, tokens: TokenCounts(input: input), estimatedCost: .zero)]
        )
    }
}
