import Domain

/// Capacidade de guardar e recuperar a credencial do provedor.
public protocol CredentialStore: Sendable {
    func credential() async -> String?
    func save(_ credential: String) async throws
    func clear() async
}
