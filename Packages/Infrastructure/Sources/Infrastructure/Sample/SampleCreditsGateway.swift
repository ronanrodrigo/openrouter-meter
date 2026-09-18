import Application
import Domain

/// Retrato de crédito fixo, para pré-visualizações e testes.
///
/// Não faz nenhuma entrada/saída: não toca em rede, em disco nem no relógio do sistema,
/// de modo que a interface SwiftUI pode ser montada em pré-visualização sem credencial real
/// e os testes podem comparar valores exatos.
public struct SampleCreditsGateway: CreditsGateway {
    /// Saldo fixo exibido pelas pré-visualizações: US$ 91,90 restantes de US$ 210,00.
    public static let snapshot = AccountSnapshot(
        totalCredits: Money(dollars: 210),
        totalUsage: Money(dollars: 118.100719069),
        dailyUsage: Money(dollars: 4.82),
        weeklyUsage: Money(dollars: 21.44),
        monthlyUsage: Money(dollars: 56.09),
        isFreeTier: false,
        freeModelQuota: FreeModelQuota(used: 28, limit: 1000)
    )

    public init() {}

    public func accountSnapshot() async throws -> AccountSnapshot {
        Self.snapshot
    }
}
