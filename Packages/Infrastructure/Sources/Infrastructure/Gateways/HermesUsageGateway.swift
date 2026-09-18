import Application
import Domain
import Foundation
import SQLite3

/// Lê o histórico local de consumo do Hermes direto do `state.db`.
///
/// O banco é aberto somente para leitura (`SQLITE_OPEN_READONLY`), em uma conexão de vida
/// curta por consulta, para não interferir no processo que escreve nele. Quando o arquivo
/// não existe, não é um banco válido ou ainda não tem a tabela `session_model_usage` — o que
/// é normal antes da primeira execução —, o adaptador devolve `[]` em vez de falhar:
/// ausência de histórico não é erro de contrato.
public struct HermesUsageGateway: UsageGateway {
    private let databasePath: URL

    public init(databasePath: URL) {
        self.databasePath = databasePath
    }

    public var source: UsageSource {
        .localHermes
    }

    public func windows(now: UnixTimestamp) async throws -> [UsageWindow] {
        let calendar = Calendar.current
        let reference = Date(timeIntervalSince1970: now.seconds)
        let startOfToday = calendar.startOfDay(for: reference)
        let startOfSevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday

        guard let today = readModels(since: startOfToday.timeIntervalSince1970),
              let week = readModels(since: startOfSevenDaysAgo.timeIntervalSince1970)
        else { return [] }

        return [
            Self.window(kind: .today, models: today),
            Self.window(kind: .lastSevenDays, models: week),
        ]
    }

    /// Agrega o consumo por modelo desde um instante; `nil` quando o banco não é legível.
    ///
    /// O custo prioriza o valor efetivamente cobrado (`actual_cost_usd`) e só cai para a
    /// estimativa (`estimated_cost_usd`) quando o primeiro é zero ou nulo.
    private func readModels(since start: Double) -> [ModelUsage]? {
        var handle: OpaquePointer?
        guard sqlite3_open_v2(databasePath.path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database = handle
        else {
            if let handle {
                sqlite3_close(handle)
            }
            return nil
        }
        defer { sqlite3_close(database) }

        let sql = """
        SELECT model,
               COALESCE(SUM(api_call_count), 0),
               COALESCE(SUM(input_tokens), 0),
               COALESCE(SUM(output_tokens), 0),
               COALESCE(SUM(cache_read_tokens), 0),
               COALESCE(SUM(cache_write_tokens), 0),
               COALESCE(SUM(reasoning_tokens), 0),
               COALESCE(SUM(COALESCE(NULLIF(actual_cost_usd, 0), estimated_cost_usd, 0)), 0)
        FROM session_model_usage
        WHERE last_seen >= ?
        GROUP BY model
        ORDER BY SUM(input_tokens) DESC
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_double(statement, 1, start)

        var collected: [ModelUsage] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let name = sqlite3_column_text(statement, 0) else { continue }
            collected.append(
                ModelUsage(
                    model: String(cString: name),
                    calls: Int(sqlite3_column_int64(statement, 1)),
                    tokens: TokenCounts(
                        input: Int(sqlite3_column_int64(statement, 2)),
                        output: Int(sqlite3_column_int64(statement, 3)),
                        cacheRead: Int(sqlite3_column_int64(statement, 4)),
                        cacheWrite: Int(sqlite3_column_int64(statement, 5)),
                        reasoning: Int(sqlite3_column_int64(statement, 6))
                    ),
                    estimatedCost: Money(dollars: sqlite3_column_double(statement, 7))
                )
            )
        }
        return collected
    }

    /// Consolida os modelos de uma janela em tokens, chamadas e custo.
    private static func window(kind: UsageWindowKind, models: [ModelUsage]) -> UsageWindow {
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
