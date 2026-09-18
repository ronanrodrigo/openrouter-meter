import Application
import Foundation

/// Credencial mantida apenas em memória.
///
/// Usada nos previews e nos testes — nunca no aplicativo em execução, onde a credencial
/// mora no Keychain do sistema.
actor InMemoryCredentialStore: CredentialStore {
    private var value: String?

    init(value: String? = nil) {
        self.value = value
    }

    func credential() async -> String? {
        value
    }

    func save(_ credential: String) async throws {
        value = credential
    }

    func clear() async {
        value = nil
    }
}
