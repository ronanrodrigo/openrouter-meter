import Application
import Domain
import Foundation
import Infrastructure

/// Único ponto do aplicativo que instancia a camada de infraestrutura.
///
/// A composição lê a credencial, escolhe a fonte de consumo correspondente — atividade
/// oficial da conta quando existe chave de provisioning, histórico local do Hermes quando
/// não existe — e sabe se remontar quando a credencial muda.
struct CompositionRoot: Sendable {
    let reportService: BuildUsageReportService
    let credentialStore: CredentialStore

    /// Como remontar a composição para outra credencial. `nil` quando a composição não
    /// depende dela (amostras e testes).
    private let remount: (@Sendable (String?) -> CompositionRoot)?

    init(
        reportService: BuildUsageReportService,
        credentialStore: CredentialStore,
        remount: (@Sendable (String?) -> CompositionRoot)? = nil
    ) {
        self.reportService = reportService
        self.credentialStore = credentialStore
        self.remount = remount
    }

    /// Composição a partir de capacidades já existentes (testes e amostras).
    init(
        credits: CreditsGateway,
        usage: UsageGateway,
        credentialStore: CredentialStore,
        now: @escaping @Sendable () -> UnixTimestamp = CompositionRoot.systemNow
    ) {
        self.init(
            reportService: BuildUsageReportService(credits: credits, usage: usage, now: now),
            credentialStore: credentialStore
        )
    }

    /// Composição equivalente usando a credencial informada.
    ///
    /// Sem uma origem de remontagem devolve a própria composição — é o caso das amostras,
    /// em que os gateways não dependem da credencial.
    func remounting(credential: String?) -> CompositionRoot {
        remount?(credential) ?? self
    }

    /// Composição de produção.
    static func live() async -> CompositionRoot {
        let credentialStore = FirstAvailableCredentialStore(
            primary: KeychainCredentialStore(
                service: InfrastructureDefaults.keychainService,
                account: InfrastructureDefaults.keychainAccount
            ),
            secondary: HermesEnvironmentCredentialStore(
                envFilePath: InfrastructureDefaults.hermesEnvironmentFileURL()
            )
        )
        let credential = await credentialStore.credential()?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return make(credentialStore: credentialStore, provisioningKey: credential)
    }

    /// Composição de amostra, sem rede — para previews e demonstrações.
    static func sample() -> CompositionRoot {
        CompositionRoot(
            credits: SampleCreditsGateway(),
            usage: SampleUsageGateway(),
            credentialStore: InMemoryCredentialStore()
        )
    }

    /// Relógio do sistema, em tempo Unix.
    static func systemNow() -> UnixTimestamp {
        UnixTimestamp(seconds: Date().timeIntervalSince1970)
    }

    /// Monta gateways para uma credencial específica, mantendo a memória de remontagem.
    private static func make(credentialStore: CredentialStore, provisioningKey: String?) -> CompositionRoot {
        let baseURL = InfrastructureDefaults.openRouterBaseURL
        let session = URLSession.shared

        let credits = OpenRouterCreditsGateway(
            apiKey: provisioningKey ?? "",
            baseURL: baseURL,
            session: session
        )

        let usage: UsageGateway = if let provisioningKey, !provisioningKey.isEmpty {
            FallbackUsageGateway(
                primary: OpenRouterActivityGateway(
                    provisioningKey: provisioningKey,
                    baseURL: baseURL,
                    session: session
                ),
                secondary: HermesUsageGateway(
                    databasePath: InfrastructureDefaults.hermesStateDatabaseURL()
                )
            )
        } else {
            HermesUsageGateway(
                databasePath: InfrastructureDefaults.hermesStateDatabaseURL()
            )
        }

        return CompositionRoot(
            reportService: BuildUsageReportService(credits: credits, usage: usage, now: systemNow),
            credentialStore: credentialStore,
            remount: { key in make(credentialStore: credentialStore, provisioningKey: key) }
        )
    }
}
