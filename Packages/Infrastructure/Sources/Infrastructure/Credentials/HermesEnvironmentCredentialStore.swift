import Application
import Domain
import Foundation

/// Recupera a credencial já configurada no ambiente do Hermes (`~/.hermes/.env`).
///
/// É a fonte secundária: quando o usuário nunca digitou uma chave no aplicativo, a chave que
/// o Hermes já usa é aproveitada, evitando configuração duplicada. O arquivo pertence ao
/// Hermes, então a gravação é recusada com `UsageError.unavailable` — quem quis alterá-lo
/// deve editá-lo, não o aplicativo — e a limpeza é uma operação vazia.
public struct HermesEnvironmentCredentialStore: CredentialStore {
    private let envFilePath: URL

    public init(envFilePath: URL = InfrastructureDefaults.hermesEnvironmentFileURL()) {
        self.envFilePath = envFilePath
    }

    public func credential() async -> String? {
        guard let contents = try? String(contentsOf: envFilePath, encoding: .utf8) else {
            return nil
        }
        return Self.value(for: "OPENROUTER_API_KEY", in: contents)
    }

    public func save(_ credential: String) async throws {
        throw UsageError.unavailable("o arquivo .env do Hermes é somente leitura para o aplicativo")
    }

    public func clear() async {
        // Nada a fazer: o arquivo .env não é gerenciado pelo aplicativo.
    }

    /// Extrai o valor de uma chave em um conteúdo no formato `.env`.
    ///
    /// Aceita `export CHAVE=valor`, linhas em branco e comentários, e remove aspas simples
    /// ou duplas que envolvam o valor.
    static func value(for key: String, in contents: String) -> String? {
        for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: false) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            if line.hasPrefix("export ") {
                line = String(line.dropFirst("export ".count)).trimmingCharacters(in: .whitespaces)
            }

            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces) == key else { continue }

            var value = parts[1].trimmingCharacters(in: .whitespaces)
            if value.count >= 2,
               (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            return value.isEmpty ? nil : value
        }
        return nil
    }
}
