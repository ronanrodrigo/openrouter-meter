import Application
import Domain
import Foundation
import Security

/// Guarda a credencial do OpenRouter no Keychain do macOS.
///
/// Usa `kSecClassGenericPassword` com serviço e conta fixos. A estrutura carrega apenas os
/// identificadores (ambos `String`, portanto `Sendable`); o `SecItem` é chamado sob demanda
/// e nenhum estado mutável é compartilhado, o que dispensa `@unchecked Sendable`.
///
/// A gravação usa `SecItemUpdate` quando o item já existe e `SecItemAdd` quando não existe,
/// evitando depender de `SecItemDelete` prévio que poderia apagar a credencial em caso de
/// falha intermediária. Ausência de item não é erro: `credential()` devolve `nil`.
public struct KeychainCredentialStore: CredentialStore {
    private let service: String
    private let account: String

    public init(
        service: String = InfrastructureDefaults.keychainService,
        account: String = InfrastructureDefaults.keychainAccount
    ) {
        self.service = service
        self.account = account
    }

    public func credential() async -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else { return nil }

        return value
    }

    public func save(_ credential: String) async throws {
        guard let data = credential.data(using: .utf8) else {
            throw UsageError.invalidResponse("credencial não é texto UTF-8 válido")
        }

        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var attributes = baseQuery
            attributes[kSecValueData as String] = data
            let addStatus = SecItemAdd(attributes as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw UsageError.unavailable("Keychain recusou a gravação (status \(addStatus))")
            }
        default:
            throw UsageError.unavailable("Keychain recusou a atualização (status \(updateStatus))")
        }
    }

    public func clear() async {
        // A limpeza é intencionalmente silenciosa: o item pode não existir.
        _ = SecItemDelete(baseQuery as CFDictionary)
    }

    /// Consulta mínima compartilhada por leitura, gravação e remoção.
    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
