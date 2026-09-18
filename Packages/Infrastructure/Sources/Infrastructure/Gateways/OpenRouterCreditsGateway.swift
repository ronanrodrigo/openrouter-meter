import Application
import Domain
import Foundation

/// Lê o crédito da conta combinando `GET /credits` com `GET /key`.
///
/// `/credits` traz o total contratado e o consumo acumulado; `/key` complementa com o uso
/// diário, semanal e mensal, o indicador de plano gratuito e a cota de modelos gratuitos.
/// O saldo é obrigatório — sem ele não existe retrato. Os complementos são opcionais: se
/// `/key` falhar, o retrato ainda é útil e é devolvido com os campos complementares zerados.
public struct OpenRouterCreditsGateway: CreditsGateway {
    private let client: OpenRouterHTTPClient

    public init(
        apiKey: String,
        baseURL: URL = InfrastructureDefaults.openRouterBaseURL,
        session: URLSession = .shared
    ) {
        client = OpenRouterHTTPClient(baseURL: baseURL, apiKey: apiKey, session: session)
    }

    public func accountSnapshot() async throws -> AccountSnapshot {
        async let creditsBody = client.get("credits")
        async let keyBody = client.get("key")

        let credits: CreditsPayload = try await client.decode(
            CreditsResponse.self,
            from: creditsBody
        ).data

        // Complemento best-effort: uma falha aqui não derruba o saldo já conhecido.
        let key: KeyPayload? = if let body = try? await keyBody {
            try? client.decode(KeyResponse.self, from: body).data
        } else {
            nil
        }

        return AccountSnapshot(
            totalCredits: Money(dollars: credits.totalCredits),
            totalUsage: Money(dollars: credits.totalUsage),
            dailyUsage: Money(dollars: key?.usageDaily ?? 0),
            weeklyUsage: Money(dollars: key?.usageWeekly ?? 0),
            monthlyUsage: Money(dollars: key?.usageMonthly ?? 0),
            isFreeTier: key?.isFreeTier ?? false,
            freeModelQuota: key?.freeModelDailyRequests.map {
                FreeModelQuota(used: $0.used, limit: $0.limit)
            }
        )
    }
}
