import Application
import Domain
import Foundation
@testable import OpenRouterMeter
import Testing

/// Espaço fixo (U+00A0) que o formatador de moeda do sistema coloca entre `US$` e o número.
private let nbsp = "\u{00A0}"

/// Gateway de crédito controlado pelo teste — nunca toca a rede.
private struct StubCreditsGateway: CreditsGateway {
    var snapshot: AccountSnapshot
    var error: UsageError?

    func accountSnapshot() async throws -> AccountSnapshot {
        if let error {
            throw error
        }
        return snapshot
    }
}

/// Gateway de crédito que conta quantas leituras foram pedidas.
private actor CountingCreditsGateway: CreditsGateway {
    private(set) var calls = 0
    private let snapshot: AccountSnapshot

    init(snapshot: AccountSnapshot = TestFixtures.account) {
        self.snapshot = snapshot
    }

    func accountSnapshot() async throws -> AccountSnapshot {
        calls += 1
        return snapshot
    }
}

/// Gateway de consumo controlado pelo teste — nunca toca a rede.
private struct StubUsageGateway: UsageGateway {
    var source: UsageSource = .accountActivity
    var windows: [UsageWindow] = []
    var error: UsageError?

    func windows(now: UnixTimestamp) async throws -> [UsageWindow] {
        if let error {
            throw error
        }
        return windows
    }
}

/// Relógio de teste que o próprio teste faz avançar.
private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ date: Date) {
        current = date
    }

    var date: Date {
        lock.withLock { current }
    }

    func advance(_ interval: TimeInterval) {
        lock.withLock { current = current.addingTimeInterval(interval) }
    }
}

@MainActor
struct UsageViewModelTests {
    private let ptBR = Locale(identifier: "pt_BR")

    private func makeViewModel(
        credits: any CreditsGateway = StubCreditsGateway(snapshot: TestFixtures.account),
        usage: any UsageGateway = StubUsageGateway(windows: [TestFixtures.todayWindow]),
        storedCredential: String? = "sk-or-v1-teste",
        clock: TestClock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
    ) -> UsageViewModel {
        let composition = CompositionRoot(
            credits: credits,
            usage: usage,
            credentialStore: InMemoryCredentialStore(value: storedCredential),
            now: { TestFixtures.capturedAt }
        )
        return UsageViewModel(
            composition: composition,
            defaults: UserDefaults(suiteName: "dev.ronanrodrigo.OpenRouterMeterTests.\(UUID().uuidString)") ??
                .standard,
            locale: ptBR,
            now: { clock.date }
        )
    }

    // MARK: - Leitura

    @Test("Leitura bem-sucedida preenche relatório e estado")
    func refreshSucceeds() async {
        let viewModel = makeViewModel()

        await viewModel.refresh()

        #expect(viewModel.loadState == .loaded)
        #expect(viewModel.report != nil)
        #expect(viewModel.report?.windows.count == 1)
        #expect(viewModel.report?.source == .accountActivity)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.hasStoredCredential)
        #expect(viewModel.lastRefresh != nil)
    }

    @Test("Chave recusada vira mensagem em pt-BR")
    func refreshMapsUnauthorized() async {
        let viewModel = makeViewModel(
            credits: StubCreditsGateway(snapshot: TestFixtures.account, error: .unauthorized)
        )

        await viewModel.refresh()

        #expect(viewModel.report == nil)
        #expect(viewModel.errorMessage?.contains("recusada") == true)
    }

    @Test("Falha de rede vira mensagem em pt-BR")
    func refreshMapsNetworkFailure() async {
        let viewModel = makeViewModel(
            credits: StubCreditsGateway(snapshot: TestFixtures.account, error: .network("sem rota"))
        )

        await viewModel.refresh()

        #expect(viewModel.errorMessage?.contains("conexão") == true)
    }

    @Test("Falha de rede no consumo preserva o saldo")
    func refreshKeepsAccountWhenUsageFails() async {
        let viewModel = makeViewModel(
            usage: StubUsageGateway(source: .localHermes, windows: [], error: .network("sem rota"))
        )

        await viewModel.refresh()

        #expect(viewModel.loadState == .loaded)
        #expect(viewModel.report?.windows.isEmpty == true)
        #expect(viewModel.report?.account.remaining == Money(dollars: 91.90))
    }

    @Test("Sem credencial o erro pede a chave em Ajustes")
    func refreshMapsMissingCredential() async {
        let viewModel = makeViewModel(
            credits: StubCreditsGateway(snapshot: TestFixtures.account, error: .missingCredential),
            storedCredential: nil
        )

        await viewModel.refresh()

        #expect(viewModel.errorMessage?.contains("Ajustes") == true)
        #expect(!viewModel.hasStoredCredential)
    }

    // MARK: - Título da barra

    @Test("Título da barra reflete o modo escolhido")
    func menuBarTitlePerMode() async {
        let viewModel = makeViewModel()
        await viewModel.refresh()

        #expect(viewModel.menuBarDisplayMode == .remainingBalance)
        #expect(viewModel.menuBarTitle == "US$\(nbsp)91,90")

        viewModel.menuBarDisplayMode = .todayCost
        #expect(viewModel.menuBarTitle == "US$\(nbsp)12,34")
    }

    @Test("Sem dados a barra mostra um traço")
    func menuBarTitleWithoutReport() {
        let viewModel = makeViewModel()

        #expect(viewModel.report == nil)
        #expect(viewModel.menuBarTitle == "—")
    }

    // MARK: - Ajustes persistidos

    @Test("Ajustes sobrevivem a uma nova instância")
    func settingsArePersisted() {
        let suiteName = "dev.ronanrodrigo.OpenRouterMeterTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard

        let first = UsageViewModel(defaults: defaults, locale: ptBR)
        first.menuBarDisplayMode = .todayCost
        first.refreshInterval = .fifteenMinutes

        let second = UsageViewModel(defaults: defaults, locale: ptBR)
        #expect(second.menuBarDisplayMode == .todayCost)
        #expect(second.refreshInterval == .fifteenMinutes)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("Sem ajustes salvos o padrão é saldo restante a cada 5 minutos")
    func settingsDefaults() {
        let suiteName = "dev.ronanrodrigo.OpenRouterMeterTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard

        let viewModel = UsageViewModel(defaults: defaults, locale: ptBR)
        #expect(viewModel.menuBarDisplayMode == .remainingBalance)
        #expect(viewModel.refreshInterval == .fiveMinutes)
        #expect(viewModel.refreshInterval.seconds == 300)

        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Ciclo de vida

    @Test("Painel recém-atualizado não relê ao abrir")
    func refreshOnOpenSkipsFreshReport() async {
        let credits = CountingCreditsGateway()
        let viewModel = makeViewModel(credits: credits)

        await viewModel.refresh()
        #expect(await credits.calls == 1)

        await viewModel.refreshOnOpen()
        #expect(await credits.calls == 1)
    }

    @Test("Painel com dado velho relê ao abrir")
    func refreshOnOpenRefreshesStaleReport() async {
        let credits = CountingCreditsGateway()
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let viewModel = makeViewModel(credits: credits, clock: clock)

        await viewModel.refresh()
        clock.advance(600)
        await viewModel.refreshOnOpen()

        #expect(await credits.calls == 2)
        #expect(viewModel.loadState == .loaded)
    }

    @Test("start inicia a atualização periódica e stop a encerra")
    func startAndStop() async {
        let viewModel = makeViewModel()

        await viewModel.start()
        #expect(viewModel.loadState == .loaded)

        viewModel.stop()
        await viewModel.start()
        #expect(viewModel.loadState == .loaded)
        viewModel.stop()
    }

    // MARK: - Credencial

    @Test("Credencial guardada é usada e pode ser removida")
    func credentialLifecycle() async {
        let store = InMemoryCredentialStore()
        let composition = CompositionRoot(
            credits: StubCreditsGateway(snapshot: TestFixtures.account),
            usage: StubUsageGateway(windows: [TestFixtures.todayWindow]),
            credentialStore: store,
            now: { TestFixtures.capturedAt }
        )
        let viewModel = UsageViewModel(
            composition: composition,
            defaults: UserDefaults(suiteName: "dev.ronanrodrigo.OpenRouterMeterTests.\(UUID().uuidString)") ??
                .standard,
            locale: ptBR
        )

        await viewModel.saveCredential("  sk-or-v1-nova  ")
        #expect(await store.credential() == "sk-or-v1-nova")
        #expect(viewModel.hasStoredCredential)
        #expect(viewModel.loadState == .loaded)

        await viewModel.removeCredential()
        #expect(await store.credential() == nil)
        #expect(!viewModel.hasStoredCredential)
    }
}
