import Domain

/// Capacidade de ler o consumo detalhado (tokens, chamadas e modelos) por janela.
public protocol UsageGateway: Sendable {
    /// Origem dos dados que este adaptador produz.
    var source: UsageSource { get }

    func windows(now: UnixTimestamp) async throws -> [UsageWindow]
}
