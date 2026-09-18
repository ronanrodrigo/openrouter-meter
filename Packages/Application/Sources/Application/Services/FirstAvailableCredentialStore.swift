import Domain

/// Guarda a credencial na primeira fonte utilizável; gravações vão para a fonte primária.
///
/// Permite ao aplicativo usar a chave digitada pelo usuário no Keychain e, quando ela não
/// existe, aproveitar a chave já configurada no ambiente do Hermes.
public struct FirstAvailableCredentialStore: CredentialStore {
    private let primary: CredentialStore
    private let secondary: CredentialStore

    public init(primary: CredentialStore, secondary: CredentialStore) {
        self.primary = primary
        self.secondary = secondary
    }

    public func credential() async -> String? {
        if let value = await primary.credential() {
            return value
        }
        return await secondary.credential()
    }

    public func save(_ credential: String) async throws {
        try await primary.save(credential)
    }

    public func clear() async {
        await primary.clear()
    }
}
