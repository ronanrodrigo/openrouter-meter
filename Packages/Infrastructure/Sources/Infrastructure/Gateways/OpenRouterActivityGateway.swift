import Application
import Domain
import Foundation

/// Lê o consumo detalhado da conta oficial via `GET /activity`.
///
/// O endpoint exige uma chave de *provisioning*; com uma chave de inferência comum ele
/// responde `403`. Nesse caso o erro é traduzido para `UsageError.unavailable`, o que faz
/// o `FallbackUsageGateway` assumir com o histórico local do Hermes em vez de acusar a
/// credencial como inválida.
public struct OpenRouterActivityGateway: UsageGateway {
    private let client: OpenRouterHTTPClient

    public init(
        provisioningKey: String,
        baseURL: URL = InfrastructureDefaults.openRouterBaseURL,
        session: URLSession = .shared
    ) {
        client = OpenRouterHTTPClient(baseURL: baseURL, apiKey: provisioningKey, session: session)
    }

    public var source: UsageSource {
        .accountActivity
    }

    public func windows(now: UnixTimestamp) async throws -> [UsageWindow] {
        let body = try await client.get("activity", forbiddenMeansUnavailable: true)
        let entries = try client.decode(ActivityResponse.self, from: body).data

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: now.seconds))
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: today) ?? today

        let dated = entries.compactMap { entry -> (Date, ActivityEntry)? in
            guard let day = Self.day(from: entry.date, calendar: calendar) else { return nil }
            return (day, entry)
        }

        return [
            Self.window(kind: .today, entries: dated.filter { $0.0 >= today }),
            Self.window(kind: .lastSevenDays, entries: dated.filter { $0.0 >= sevenDaysAgo }),
        ]
    }

    /// Interpreta a data `yyyy-MM-dd` do endpoint no calendário local.
    private static func day(from text: String, calendar: Calendar) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        return calendar.date(from: components)
    }

    /// Acumulador do consumo de um modelo dentro da janela.
    private struct ModelAccumulator {
        var calls = 0
        var tokens = TokenCounts.zero
        var cost = Money.zero
    }

    /// Agrega as entradas de uma janela por modelo, ordenando por tokens de entrada.
    private static func window(
        kind: UsageWindowKind,
        entries: [(Date, ActivityEntry)]
    ) -> UsageWindow {
        var byModel: [String: ModelAccumulator] = [:]

        for (_, entry) in entries {
            let tokens = TokenCounts(
                input: entry.promptTokens ?? 0,
                output: entry.completionTokens ?? 0,
                reasoning: entry.reasoningTokens ?? 0
            )
            var current = byModel[entry.model] ?? ModelAccumulator()
            current.calls += entry.requests ?? 0
            current.tokens = TokenCounts(
                input: current.tokens.input + tokens.input,
                output: current.tokens.output + tokens.output,
                cacheRead: current.tokens.cacheRead + tokens.cacheRead,
                cacheWrite: current.tokens.cacheWrite + tokens.cacheWrite,
                reasoning: current.tokens.reasoning + tokens.reasoning
            )
            current.cost += Money(dollars: entry.usage ?? 0)
            byModel[entry.model] = current
        }

        let models = byModel
            .map { ModelUsage(
                model: $0.key,
                calls: $0.value.calls,
                tokens: $0.value.tokens,
                estimatedCost: $0.value.cost
            ) }
            .sorted { $0.tokens.input > $1.tokens.input }

        let tokens = models.reduce(TokenCounts.zero) { partial, model in
            TokenCounts(
                input: partial.input + model.tokens.input,
                output: partial.output + model.tokens.output,
                cacheRead: partial.cacheRead + model.tokens.cacheRead,
                cacheWrite: partial.cacheWrite + model.tokens.cacheWrite,
                reasoning: partial.reasoning + model.tokens.reasoning
            )
        }
        let calls = models.reduce(0) { $0 + $1.calls }
        let cost = models.reduce(Money.zero) { $0 + $1.estimatedCost }

        return UsageWindow(kind: kind, tokens: tokens, calls: calls, cost: cost, models: models)
    }
}
