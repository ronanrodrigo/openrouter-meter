import Application
import Domain
import Foundation
@testable import Infrastructure
import Testing

private let creditsJSON = """
{"data":{"total_credits":210,"total_usage":118.100719069}}
"""

private let keyJSON = """
{"data":{"label":"sk-or-v1-...","usage_daily":4.82,"usage_weekly":21.44,"usage_monthly":56.09,
"is_free_tier":false,"free_model_daily_requests":{"used":28,"limit":1000}}}
"""

/// Manipulador que responde `/credits` e `/key` com corpos fixos.
private func creditsAndKeyHandler(_ request: URLRequest) -> StubResponse {
    switch request.url?.lastPathComponent {
    case "credits": StubURLProtocol.json(creditsJSON)
    case "key": StubURLProtocol.json(keyJSON)
    default: StubURLProtocol.json("{}", status: 404)
    }
}

@Suite("OpenRouterCreditsGateway")
struct OpenRouterCreditsGatewayTests {
    @Test("combina /credits e /key em um AccountSnapshot")
    func combinesCreditsAndKey() async throws {
        let baseURL = StubURLProtocol.makeBaseURL(creditsAndKeyHandler)
        let gateway = OpenRouterCreditsGateway(
            apiKey: "chave-de-teste",
            baseURL: baseURL,
            session: StubURLProtocol.makeSession()
        )

        let snapshot = try await gateway.accountSnapshot()

        #expect(snapshot.totalCredits == Money(dollars: 210))
        #expect(snapshot.totalUsage == Money(dollars: 118.100719069))
        #expect(snapshot.remaining.micros == 91_899_281)
        #expect(snapshot.dailyUsage == Money(dollars: 4.82))
        #expect(snapshot.weeklyUsage == Money(dollars: 21.44))
        #expect(snapshot.monthlyUsage == Money(dollars: 56.09))
        #expect(snapshot.isFreeTier == false)
        #expect(snapshot.freeModelQuota == FreeModelQuota(used: 28, limit: 1000))
    }

    @Test("envia a credencial no cabeçalho Authorization")
    func sendsBearerToken() async throws {
        let baseURL = StubURLProtocol.makeBaseURL(creditsAndKeyHandler)
        let gateway = OpenRouterCreditsGateway(
            apiKey: "sk-or-v1-segredo",
            baseURL: baseURL,
            session: StubURLProtocol.makeSession()
        )

        _ = try await gateway.accountSnapshot()

        let requests = StubURLProtocol.requests(for: baseURL)
        #expect(requests.count == 2)
        for request in requests {
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-or-v1-segredo")
            #expect(request.url?.path.hasSuffix("/api/v1/credits") == true
                || request.url?.path.hasSuffix("/api/v1/key") == true)
        }
    }

    @Test("devolve o saldo mesmo quando /key falha")
    func degradesWhenKeyEndpointFails() async throws {
        let baseURL = StubURLProtocol.makeBaseURL { request in
            request.url?.lastPathComponent == "credits"
                ? StubURLProtocol.json(creditsJSON)
                : StubURLProtocol.json("{}", status: 500)
        }
        let gateway = OpenRouterCreditsGateway(
            apiKey: "chave",
            baseURL: baseURL,
            session: StubURLProtocol.makeSession()
        )

        let snapshot = try await gateway.accountSnapshot()

        #expect(snapshot.totalCredits == Money(dollars: 210))
        #expect(snapshot.dailyUsage == .zero)
        #expect(snapshot.freeModelQuota == nil)
    }

    @Test("corpo fora do contrato vira invalidResponse")
    func invalidBody() async throws {
        let baseURL = StubURLProtocol.makeBaseURL { _ in StubURLProtocol.json("{\"data\":{}}") }
        let gateway = OpenRouterCreditsGateway(
            apiKey: "chave",
            baseURL: baseURL,
            session: StubURLProtocol.makeSession()
        )

        await #expect(throws: UsageError.self) {
            _ = try await gateway.accountSnapshot()
        }
        do {
            _ = try await gateway.accountSnapshot()
        } catch let error as UsageError {
            guard case .invalidResponse = error else {
                Issue.record("esperava invalidResponse, veio \(error)")
                return
            }
        }
    }
}

@Suite("Tradução de erro HTTP")
struct HTTPErrorTranslationTests {
    @Test("401 vira unauthorized")
    func unauthorized() async throws {
        let baseURL = StubURLProtocol.makeBaseURL { _ in StubURLProtocol.json("{\"error\":\"nope\"}", status: 401) }
        let gateway = OpenRouterCreditsGateway(
            apiKey: "chave",
            baseURL: baseURL,
            session: StubURLProtocol.makeSession()
        )

        await #expect(throws: UsageError.unauthorized) {
            _ = try await gateway.accountSnapshot()
        }
    }

    @Test("403 vira unauthorized")
    func forbidden() async throws {
        let baseURL = StubURLProtocol.makeBaseURL { _ in StubURLProtocol.json("{}", status: 403) }
        let gateway = OpenRouterCreditsGateway(
            apiKey: "chave",
            baseURL: baseURL,
            session: StubURLProtocol.makeSession()
        )

        await #expect(throws: UsageError.unauthorized) {
            _ = try await gateway.accountSnapshot()
        }
    }

    @Test("429 vira rateLimited")
    func rateLimited() async throws {
        let baseURL = StubURLProtocol.makeBaseURL { _ in StubURLProtocol.json("{}", status: 429) }
        let gateway = OpenRouterCreditsGateway(
            apiKey: "chave",
            baseURL: baseURL,
            session: StubURLProtocol.makeSession()
        )

        await #expect(throws: UsageError.rateLimited) {
            _ = try await gateway.accountSnapshot()
        }
    }

    @Test("outro status não-2xx vira invalidResponse")
    func invalidResponseStatus() async throws {
        let baseURL = StubURLProtocol.makeBaseURL { _ in StubURLProtocol.json("{}", status: 503) }
        let gateway = OpenRouterCreditsGateway(
            apiKey: "chave",
            baseURL: baseURL,
            session: StubURLProtocol.makeSession()
        )

        do {
            _ = try await gateway.accountSnapshot()
            Issue.record("esperava falha")
        } catch let error as UsageError {
            guard case let .invalidResponse(detail) = error else {
                Issue.record("esperava invalidResponse, veio \(error)")
                return
            }
            #expect(detail.contains("503"))
        }
    }

    @Test("URLError vira network e nenhum erro de URLSession escapa")
    func networkFailure() async throws {
        let baseURL = StubURLProtocol.makeBaseURL { _ in .failure(URLError(.notConnectedToInternet)) }
        let gateway = OpenRouterCreditsGateway(
            apiKey: "chave",
            baseURL: baseURL,
            session: StubURLProtocol.makeSession()
        )

        do {
            _ = try await gateway.accountSnapshot()
            Issue.record("esperava falha")
        } catch let error as UsageError {
            guard case .network = error else {
                Issue.record("esperava network, veio \(error)")
                return
            }
        }
    }
}
