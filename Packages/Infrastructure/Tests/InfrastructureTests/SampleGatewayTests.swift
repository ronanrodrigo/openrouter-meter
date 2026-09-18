import Application
import Domain
import Foundation
@testable import Infrastructure
import Testing

@Suite("Adaptadores Sample")
struct SampleGatewayTests {
    @Test("retrato de exemplo: US$ 91,90 restantes de US$ 210,00")
    func sampleSnapshot() async throws {
        let snapshot = try await SampleCreditsGateway().accountSnapshot()

        #expect(snapshot.totalCredits == Money(dollars: 210))
        #expect(snapshot.totalUsage == Money(dollars: 118.100719069))
        #expect(snapshot.remaining.micros == 91_899_281)
        #expect(String(format: "%.2f", snapshot.remaining.dollars) == "91.90")
        #expect(snapshot.consumedFraction > 0.56 && snapshot.consumedFraction < 0.57)
        #expect(snapshot.isFreeTier == false)
        #expect(snapshot.freeModelQuota == FreeModelQuota(used: 28, limit: 1000))
    }

    @Test("duas janelas com três modelos cada, sem IO")
    func sampleWindows() async throws {
        let gateway = SampleUsageGateway()
        #expect(gateway.source == .localHermes)

        let windows = try await gateway.windows(now: UnixTimestamp(seconds: 0))
        #expect(Set(windows.map(\.kind)) == [.today, .lastSevenDays])

        for window in windows {
            #expect(window.models.count == 3)
            #expect(window.calls == window.models.reduce(0) { $0 + $1.calls })
            #expect(window.cost == window.models.reduce(Money.zero) { $0 + $1.estimatedCost })
        }

        let today = try #require(windows.first { $0.kind == .today })
        #expect(today.rankedModels.first?.model == "anthropic/claude-sonnet-4.5")
        #expect(try today.share(of: #require(today.models.first)) > 0.6)

        // Determinístico: o instante recebido não altera o resultado.
        let again = try await gateway.windows(now: UnixTimestamp(seconds: 1_800_000_000))
        #expect(again == windows)
    }

    @Test("adaptadores de exemplo são Sendable e substituíveis nos serviços da aplicação")
    func usableThroughApplicationProtocols() async throws {
        let credits: any CreditsGateway = SampleCreditsGateway()
        let usage: any UsageGateway = SampleUsageGateway()
        let service = BuildUsageReportService(
            credits: credits,
            usage: usage,
            now: { UnixTimestamp(seconds: 0) }
        )

        let report = try await service.execute()

        #expect(report.source == .localHermes)
        #expect(report.window(.today)?.models.count == 3)
        #expect(report.account.remaining == Money(micros: 91_899_281))
    }
}

@Suite("InfrastructureDefaults")
struct InfrastructureDefaultsTests {
    @Test("endereço base da API do OpenRouter")
    func baseURL() {
        #expect(InfrastructureDefaults.openRouterBaseURL.absoluteString == "https://openrouter.ai/api/v1")
    }

    @Test("identificadores do Keychain")
    func keychainIdentifiers() {
        #expect(InfrastructureDefaults.keychainService == "dev.ronanrodrigo.OpenRouterMeter")
        #expect(InfrastructureDefaults.keychainAccount == "openrouter-api-key")
    }

    @Test("caminhos do Hermes apontam para o diretório de estado")
    func hermesPaths() {
        let home = InfrastructureDefaults.hermesHomeDirectory()
        #expect(InfrastructureDefaults.hermesEnvironmentFileURL() == home.appendingPathComponent(".env"))
        #expect(InfrastructureDefaults.hermesStateDatabaseURL() == home.appendingPathComponent("state.db"))
        #expect(InfrastructureDefaults.hermesEnvironmentFileURL().lastPathComponent == ".env")
        #expect(InfrastructureDefaults.hermesStateDatabaseURL().lastPathComponent == "state.db")
    }
}
