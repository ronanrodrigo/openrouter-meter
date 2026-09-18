@testable import Domain
import Testing

@Suite("Conta e relatório")
struct AccountTests {
    private let snapshot = AccountSnapshot(
        totalCredits: Money(dollars: 210),
        totalUsage: Money(dollars: 118.100719069),
        dailyUsage: Money(dollars: 13.46),
        weeklyUsage: Money(dollars: 28.15),
        monthlyUsage: Money(dollars: 67.5),
        isFreeTier: false,
        freeModelQuota: FreeModelQuota(used: 28, limit: 1000)
    )

    @Test("saldo é crédito menos consumo")
    func remaining() {
        #expect(snapshot.remaining == Money(micros: 91_899_281))
    }

    @Test("fração consumida fica entre zero e um")
    func consumedFraction() {
        #expect(abs(snapshot.consumedFraction - 0.5624) < 0.001)
        #expect(AccountSnapshot(totalCredits: .zero, totalUsage: Money(dollars: 5)).consumedFraction == 0)
        #expect(
            AccountSnapshot(totalCredits: Money(dollars: 1), totalUsage: Money(dollars: 4))
                .consumedFraction == 1.0
        )
    }

    @Test("cota gratuita calcula restante e fração")
    func freeQuota() {
        let quota = FreeModelQuota(used: 250, limit: 1000)
        #expect(quota.remaining == 750)
        #expect(quota.fraction == 0.25)
        #expect(FreeModelQuota(used: 1200, limit: 1000).remaining == 0)
        #expect(FreeModelQuota(used: 10, limit: 0).fraction == 0)
    }

    @Test("account snapshot tem padrões para campos opcionais")
    func snapshotDefaults() {
        let minimal = AccountSnapshot(totalCredits: Money(dollars: 5), totalUsage: Money(dollars: 1))
        #expect(minimal.dailyUsage == .zero)
        #expect(minimal.weeklyUsage == .zero)
        #expect(minimal.monthlyUsage == .zero)
        #expect(minimal.isFreeTier == false)
        #expect(minimal.freeModelQuota == nil)
        #expect(minimal.remaining == Money(dollars: 4))
    }

    @Test("UnixTimestamp ordena por instante")
    func timestampOrdering() {
        #expect(UnixTimestamp(seconds: 1) < UnixTimestamp(seconds: 2))
        #expect(UnixTimestamp(seconds: 2) > UnixTimestamp(seconds: 1))
        #expect(UnixTimestamp(seconds: 3) == UnixTimestamp(seconds: 3))
    }

    @Test("relatório encontra a janela pelo tipo")
    func reportLookup() {
        let today = UsageWindow(kind: .today, tokens: .zero, calls: 0, cost: .zero, models: [])
        let report = UsageReport(
            account: snapshot,
            windows: [today],
            source: .localHermes,
            capturedAt: UnixTimestamp(seconds: 1_789_694_711)
        )
        #expect(report.window(.today)?.kind == .today)
        #expect(report.window(.lastSevenDays) == nil)
        #expect(report.source == .localHermes)
    }

    @Test("erros são comparáveis e descrevem a falha")
    func errorEquality() {
        #expect(UsageError.unauthorized == UsageError.unauthorized)
        #expect(UsageError.network("timeout") == UsageError.network("timeout"))
        #expect(UsageError.network("timeout") != UsageError.network("offline"))
        #expect(UsageError.missingCredential != UsageError.rateLimited)
        if case let .invalidResponse(reason) = UsageError.invalidResponse("sem data") {
            #expect(reason == "sem data")
        } else {
            Issue.record("esperava invalidResponse")
        }
    }
}
