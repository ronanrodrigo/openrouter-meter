import Domain

/// Capacidade de ler o crédito da conta no provedor.
public protocol CreditsGateway: Sendable {
    func accountSnapshot() async throws -> AccountSnapshot
}
