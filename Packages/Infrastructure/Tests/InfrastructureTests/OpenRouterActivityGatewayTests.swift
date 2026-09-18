import Application
import Domain
import Foundation
@testable import Infrastructure
import Testing

private let calendar = Calendar.current

/// Data no formato `yyyy-MM-dd` usado pelo endpoint `/activity`, com deslocamento em dias.
private func dayString(daysAgo: Int) -> String {
    let today = calendar.startOfDay(for: Date())
    let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 1)
}

/// Uma linha pedida ao endpoint `/activity`.
private struct ActivityRow {
    let daysAgo: Int
    let model: String
    let requests: Int
    let input: Int
    let output: Int
    let usage: Double

    init(_ daysAgo: Int, _ model: String, _ requests: Int, _ input: Int, _ output: Int, _ usage: Double) {
        self.daysAgo = daysAgo
        self.model = model
        self.requests = requests
        self.input = input
        self.output = output
        self.usage = usage
    }
}

/// Corpo de `/activity` com uma entrada por linha pedida.
private func activityJSON(_ entries: [ActivityRow]) -> String {
    let rows = entries.map { entry in
        """
        {"date":"\(dayString(daysAgo: entry.daysAgo))","model":"\(entry.model)","usage":\(entry.usage),\
        "requests":\(entry.requests),"prompt_tokens":\(entry.input),"completion_tokens":\(entry.output),\
        "reasoning_tokens":10}
        """
    }
    return "{\"data\":[\(rows.joined(separator: ","))]}"
}

@Suite("OpenRouterActivityGateway")
struct OpenRouterActivityGatewayTests {
    @Test("fonte declarada é a atividade da conta")
    func source() {
        let gateway = OpenRouterActivityGateway(provisioningKey: "chave")
        #expect(gateway.source == .accountActivity)
    }

    @Test("agrega por modelo dentro de cada janela")
    func aggregatesWindows() async throws {
        let body = activityJSON([
            ActivityRow(0, "anthropic/claude-sonnet-4.5", 4, 1000, 200, 0.50),
            ActivityRow(0, "anthropic/claude-sonnet-4.5", 2, 500, 100, 0.25),
            ActivityRow(0, "openai/gpt-5.1", 3, 300, 60, 0.10),
            ActivityRow(3, "google/gemini-3-pro", 5, 2000, 400, 1.00),
            ActivityRow(10, "fora/da-janela", 9, 9999, 999, 9.99),
        ])
        let baseURL = StubURLProtocol.makeBaseURL { _ in StubURLProtocol.json(body) }
        let gateway = OpenRouterActivityGateway(
            provisioningKey: "provisioning",
            baseURL: baseURL,
            session: StubURLProtocol.makeSession()
        )

        let windows = try await gateway.windows(now: UnixTimestamp(seconds: Date().timeIntervalSince1970))
        #expect(windows.count == 2)

        let today = try #require(windows.first { $0.kind == .today })
        #expect(today.models.count == 2)
        #expect(today.calls == 9)
        #expect(today.tokens.input == 1800)
        #expect(today.tokens.output == 360)
        #expect(today.cost == Money(dollars: 0.85))
        #expect(today.models.map(\.model) == ["anthropic/claude-sonnet-4.5", "openai/gpt-5.1"])
        #expect(today.models.first?.calls == 6)
        #expect(today.models.first?.tokens.input == 1500)

        let week = try #require(windows.first { $0.kind == .lastSevenDays })
        #expect(week.models.count == 3)
        #expect(week.models.map(\.model) == ["google/gemini-3-pro", "anthropic/claude-sonnet-4.5", "openai/gpt-5.1"])
        #expect(week.calls == 14)
        #expect(week.cost == Money(dollars: 1.85))
    }

    @Test("403 vira unavailable para liberar o fallback")
    func forbiddenMeansUnavailable() async throws {
        let baseURL = StubURLProtocol.makeBaseURL { _ in StubURLProtocol.json("{}", status: 403) }
        let gateway = OpenRouterActivityGateway(
            provisioningKey: "chave-sem-provisioning",
            baseURL: baseURL,
            session: StubURLProtocol.makeSession()
        )

        do {
            _ = try await gateway.windows(now: UnixTimestamp(seconds: 0))
            Issue.record("esperava falha")
        } catch let error as UsageError {
            guard case .unavailable = error else {
                Issue.record("esperava unavailable, veio \(error)")
                return
            }
        }
    }

    @Test("chama o endpoint /activity com Bearer")
    func hitsActivityEndpoint() async throws {
        let baseURL = StubURLProtocol.makeBaseURL { _ in StubURLProtocol.json(activityJSON([])) }
        let gateway = OpenRouterActivityGateway(
            provisioningKey: "provisioning",
            baseURL: baseURL,
            session: StubURLProtocol.makeSession()
        )

        _ = try await gateway.windows(now: UnixTimestamp(seconds: 0))

        let request = try #require(StubURLProtocol.requests(for: baseURL).first)
        #expect(request.url?.path.hasSuffix("/api/v1/activity") == true)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer provisioning")
    }
}
