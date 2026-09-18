import Application
import Domain
import Foundation
@testable import Infrastructure
import SQLite3
import Testing

/// Linha de consumo como o Hermes grava em `session_model_usage`.
private struct UsageRow {
    let model: String
    let calls: Int
    let input: Int
    let output: Int
    let cacheRead: Int
    let cacheWrite: Int
    let reasoning: Int
    let estimated: Double
    let actual: Double
    let lastSeen: Double
}

private struct FixtureError: Error {
    let message: String
}

/// Cria um banco temporário com a tabela real do Hermes e as linhas pedidas.
private func makeDatabase(_ rows: [UsageRow], createTable: Bool = true) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("hermes-state-\(UUID().uuidString).db")

    var handle: OpaquePointer?
    guard sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK,
          let database = handle
    else {
        if let handle {
            sqlite3_close(handle)
        }
        throw FixtureError(message: "não foi possível abrir o banco temporário")
    }
    defer { sqlite3_close(database) }

    if createTable {
        try execute(database, """
        CREATE TABLE session_model_usage(
            model TEXT,
            billing_provider TEXT,
            api_call_count INTEGER,
            input_tokens INTEGER,
            output_tokens INTEGER,
            cache_read_tokens INTEGER,
            cache_write_tokens INTEGER,
            reasoning_tokens INTEGER,
            estimated_cost_usd REAL,
            actual_cost_usd REAL,
            last_seen REAL
        );
        """)
    }

    for row in rows {
        try execute(database, """
        INSERT INTO session_model_usage VALUES(
            '\(row.model)', 'openrouter', \(row.calls), \(row.input), \(row.output),
            \(row.cacheRead), \(row.cacheWrite), \(row.reasoning),
            \(String(format: "%.6f", row.estimated)), \(String(format: "%.6f", row.actual)),
            \(String(format: "%.6f", row.lastSeen))
        );
        """)
    }

    return url
}

private func execute(_ database: OpaquePointer, _ sql: String) throws {
    var error: UnsafeMutablePointer<CChar>?
    let status = sqlite3_exec(database, sql, nil, nil, &error)
    guard status == SQLITE_OK else {
        let detail = error.map { String(cString: $0) } ?? "status \(status)"
        sqlite3_free(error)
        throw FixtureError(message: detail)
    }
}

private func timestamp(daysAgo: Int, addingSeconds: Double = 3600) -> Double {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
    return day.timeIntervalSince1970 + addingSeconds
}

private var now: UnixTimestamp {
    UnixTimestamp(seconds: Date().timeIntervalSince1970)
}

@Suite("HermesUsageGateway")
struct HermesUsageGatewayTests {
    @Test("fonte declarada é o histórico local")
    func source() {
        let gateway = HermesUsageGateway(databasePath: URL(fileURLWithPath: "/tmp/inexistente.db"))
        #expect(gateway.source == .localHermes)
    }

    @Test("agrega hoje e os últimos sete dias, com custo efetivo sobre estimado")
    func aggregatesRealSchema() async throws {
        let path = try makeDatabase([
            UsageRow(model: "anthropic/claude-sonnet-4.5", calls: 2, input: 100, output: 20,
                     cacheRead: 10, cacheWrite: 5, reasoning: 3,
                     estimated: 0.25, actual: 0.50, lastSeen: timestamp(daysAgo: 0)),
            UsageRow(model: "anthropic/claude-sonnet-4.5", calls: 3, input: 300, output: 60,
                     cacheRead: 0, cacheWrite: 0, reasoning: 0,
                     estimated: 0.25, actual: 0, lastSeen: timestamp(daysAgo: 1)),
            UsageRow(model: "openai/gpt-5.1", calls: 5, input: 200, output: 40,
                     cacheRead: 1, cacheWrite: 2, reasoning: 4,
                     estimated: 0.10, actual: 0, lastSeen: timestamp(daysAgo: 3)),
            UsageRow(model: "fora/da-janela", calls: 9, input: 9999, output: 9,
                     cacheRead: 0, cacheWrite: 0, reasoning: 0,
                     estimated: 9.99, actual: 9.99, lastSeen: timestamp(daysAgo: 10)),
        ])
        defer { try? FileManager.default.removeItem(at: path) }

        let windows = try await HermesUsageGateway(databasePath: path).windows(now: now)
        #expect(windows.count == 2)

        let today = try #require(windows.first { $0.kind == .today })
        #expect(today.models.map(\.model) == ["anthropic/claude-sonnet-4.5"])
        #expect(today.calls == 2)
        #expect(today.tokens == TokenCounts(input: 100, output: 20, cacheRead: 10, cacheWrite: 5, reasoning: 3))
        // actual_cost_usd (0,50) prevalece sobre estimated_cost_usd (0,25).
        #expect(today.cost == Money(dollars: 0.50))

        let week = try #require(windows.first { $0.kind == .lastSevenDays })
        // Ordenado por tokens de entrada, do maior para o menor.
        #expect(week.models.map(\.model) == ["anthropic/claude-sonnet-4.5", "openai/gpt-5.1"])
        #expect(week.models.first?.tokens.input == 400)
        #expect(week.models.first?.calls == 5)
        // 0,50 + 0,25 (estimado, pois actual é zero) = 0,75.
        #expect(week.models.first?.estimatedCost == Money(dollars: 0.75))
        #expect(week.calls == 10)
        #expect(week.tokens.input == 600)
        #expect(week.cost == Money(dollars: 0.85))
    }

    @Test("banco inexistente devolve lista vazia sem lançar erro")
    func missingDatabase() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("hermes-ausente-\(UUID().uuidString).db")

        let windows = try await HermesUsageGateway(databasePath: path).windows(now: now)

        #expect(windows.isEmpty)
    }

    @Test("banco sem a tabela devolve lista vazia sem lançar erro")
    func missingTable() async throws {
        let path = try makeDatabase([], createTable: false)
        defer { try? FileManager.default.removeItem(at: path) }

        let windows = try await HermesUsageGateway(databasePath: path).windows(now: now)

        #expect(windows.isEmpty)
    }

    @Test("janela sem linhas continua presente, com zeros")
    func emptyWindows() async throws {
        let path = try makeDatabase([])
        defer { try? FileManager.default.removeItem(at: path) }

        let windows = try await HermesUsageGateway(databasePath: path).windows(now: now)

        #expect(windows.count == 2)
        #expect(windows.allSatisfy { $0.models.isEmpty && $0.cost == .zero && $0.calls == 0 })
    }
}
