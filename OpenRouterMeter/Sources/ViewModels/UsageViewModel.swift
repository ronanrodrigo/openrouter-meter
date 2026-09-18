import Application
import Domain
import Foundation
import Observation

/// Estado único do aplicativo: relatório, situação da leitura e ajustes persistidos.
///
/// Nada de `ObservableObject`: o estado é observado pelos recursos de `Observation`.
@MainActor
@Observable
final class UsageViewModel {
    /// Situação da última leitura.
    enum LoadState: Equatable, Sendable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    /// Relatório mais recente, quando houver.
    private(set) var report: UsageReport?

    /// Situação da leitura atual.
    private(set) var loadState: LoadState = .idle

    /// Instante da última tentativa de leitura.
    private(set) var lastRefresh: Date?

    /// Se existe credencial utilizável (Keychain ou ambiente do Hermes).
    private(set) var hasStoredCredential = false

    /// O que a barra de menus mostra.
    var menuBarDisplayMode: MenuBarDisplayMode {
        didSet {
            defaults.set(menuBarDisplayMode.rawValue, forKey: Keys.menuBarDisplayMode)
        }
    }

    /// Cadência da atualização periódica.
    var refreshInterval: RefreshInterval {
        didSet {
            defaults.set(refreshInterval.rawValue, forKey: Keys.refreshInterval)
        }
    }

    private enum Keys {
        static let menuBarDisplayMode = "menuBarDisplayMode"
        static let refreshInterval = "refreshInterval"
    }

    private var composition: CompositionRoot?
    private let defaults: UserDefaults
    private let locale: Locale
    private let now: @Sendable () -> Date
    private let wait: @Sendable (Duration) async throws -> Void
    private var updateTask: Task<Void, Never>?

    init(
        composition: CompositionRoot? = nil,
        defaults: UserDefaults = .standard,
        locale: Locale = Formatters.displayLocale,
        now: @escaping @Sendable () -> Date = { Date() },
        wait: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.composition = composition
        self.defaults = defaults
        self.locale = locale
        self.now = now
        self.wait = wait
        menuBarDisplayMode = MenuBarDisplayMode(
            rawValue: defaults.string(forKey: Keys.menuBarDisplayMode) ?? ""
        ) ?? .remainingBalance
        refreshInterval = RefreshInterval(
            rawValue: defaults.integer(forKey: Keys.refreshInterval)
        ) ?? .default
    }

    // MARK: - Derivados

    /// Título exibido na barra de menus, conforme o modo escolhido.
    var menuBarTitle: String {
        Formatters.menuBarTitle(for: menuBarDisplayMode, report: report, locale: locale)
    }

    /// Origem dos dados exibidos, em pt-BR.
    var sourceLabel: String? {
        switch report?.source {
        case .accountActivity: "Atividade da conta"
        case .localHermes: "Histórico local do Hermes"
        case nil: nil
        }
    }

    var isRefreshing: Bool {
        loadState == .loading
    }

    /// Mensagem legível da falha atual, quando houver.
    var errorMessage: String? {
        if case let .failed(message) = loadState {
            return message
        }
        return nil
    }

    // MARK: - Ciclo de vida

    /// Faz a primeira leitura e passa a atualizar periodicamente.
    func start() async {
        guard updateTask == nil else { return }
        await refresh()
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    try await wait(.seconds(refreshInterval.seconds))
                } catch {
                    return
                }
                await refresh()
            }
        }
    }

    /// Encerra a atualização periódica.
    func stop() {
        updateTask?.cancel()
        updateTask = nil
    }

    /// Atualiza ao abrir o painel, desde que o último dado esteja velho.
    func refreshOnOpen() async {
        guard let lastRefresh else {
            await refresh()
            return
        }
        let threshold = min(refreshInterval.seconds, 60)
        guard now().timeIntervalSince(lastRefresh) >= threshold else { return }
        await refresh()
    }

    // MARK: - Leitura

    /// Lê o relatório mais recente. Falhas viram mensagem, nunca exceção para a view.
    func refresh() async {
        guard loadState != .loading else { return }
        guard let composition = await resolvedComposition() else { return }

        loadState = .loading
        do {
            let report = try await composition.reportService.execute()
            self.report = report
            loadState = .loaded
        } catch let error as UsageError {
            loadState = .failed(Self.message(for: error))
        } catch {
            loadState = .failed("Não foi possível ler o consumo agora.")
        }
        lastRefresh = now()
        hasStoredCredential = await composition.credentialStore.credential() != nil
    }

    /// Monta a composição na primeira necessidade e a reutiliza depois.
    private func resolvedComposition() async -> CompositionRoot? {
        if let composition {
            return composition
        }
        let resolved = await CompositionRoot.live()
        composition = resolved
        return resolved
    }

    // MARK: - Credencial

    /// Guarda a chave digitada em Ajustes e relê o relatório.
    func saveCredential(_ credential: String) async {
        let trimmed = credential.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let composition = await resolvedComposition() else { return }

        do {
            try await composition.credentialStore.save(trimmed)
        } catch {
            loadState = .failed("Não foi possível guardar a chave no Keychain.")
            return
        }

        // A chave entra na montagem dos gateways: remontamos para usá-la de imediato.
        self.composition = composition.remounting(credential: trimmed)
        hasStoredCredential = true
        await refresh()
    }

    /// Remove a chave guardada e relê o relatório.
    func removeCredential() async {
        guard let composition = await resolvedComposition() else { return }
        await composition.credentialStore.clear()
        self.composition = composition.remounting(credential: nil)
        report = nil
        hasStoredCredential = false
        await refresh()
    }

    // MARK: - Erros

    /// Mensagem em pt-BR para cada falha de domínio.
    static func message(for error: UsageError) -> String {
        switch error {
        case .missingCredential:
            "Nenhuma chave da OpenRouter configurada. Salve uma chave em Ajustes para ver o saldo."
        case .unauthorized:
            "A chave da OpenRouter foi recusada. Confira a chave em Ajustes."
        case .rateLimited:
            "A OpenRouter limitou as requisições. Tente de novo em alguns instantes."
        case .network:
            "Não foi possível falar com a OpenRouter. Verifique a conexão."
        case .invalidResponse:
            "A OpenRouter devolveu uma resposta inesperada."
        case .unavailable:
            "Esta informação não está disponível neste momento."
        }
    }
}

extension UsageViewModel {
    /// View model de amostra, sem rede — para previews.
    @MainActor
    static func preview() -> UsageViewModel {
        UsageViewModel(
            composition: .sample(),
            defaults: UserDefaults(suiteName: "dev.ronanrodrigo.OpenRouterMeter.preview") ?? .standard
        )
    }
}
