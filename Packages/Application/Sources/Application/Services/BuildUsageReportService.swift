import Domain

/// Monta o relatório exibido pelo aplicativo a partir das capacidades injetadas.
public struct BuildUsageReportService: Sendable {
    private let credits: CreditsGateway
    private let usage: UsageGateway
    private let now: @Sendable () -> UnixTimestamp

    public init(
        credits: CreditsGateway,
        usage: UsageGateway,
        now: @escaping @Sendable () -> UnixTimestamp
    ) {
        self.credits = credits
        self.usage = usage
        self.now = now
    }

    /// Busca crédito e consumo em paralelo e devolve um relatório único.
    ///
    /// O saldo é obrigatório: sem ele não há relatório. Consumo detalhado que falha
    /// apenas reduz o relatório, sem derrubar a leitura principal.
    public func execute() async throws -> UsageReport {
        let instant = now()
        async let account = credits.accountSnapshot()
        async let windows = usage.windows(now: instant)

        let snapshot = try await account
        let detailed = await (try? windows) ?? []

        return UsageReport(
            account: snapshot,
            windows: detailed,
            source: usage.source,
            capturedAt: instant
        )
    }
}
