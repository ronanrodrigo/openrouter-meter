import Foundation

/// Padrões de configuração da camada de infraestrutura.
///
/// Centraliza endereços, identificadores e caminhos para que os adaptadores não espalhem
/// constantes mágicas pelo código e para que os testes possam apontar para outro diretório.
public enum InfrastructureDefaults {
    /// URL base da API pública do OpenRouter.
    public static let openRouterBaseURL = URL(string: "https://openrouter.ai/api/v1")
        ?? URL(fileURLWithPath: "/")

    /// Serviço do Keychain usado para guardar a credencial digitada pelo usuário.
    public static let keychainService = "dev.ronanrodrigo.OpenRouterMeter"

    /// Conta do Keychain usada para guardar a credencial digitada pelo usuário.
    public static let keychainAccount = "openrouter-api-key"

    /// Diretório de estado do Hermes, respeitando `$HERMES_HOME` e caindo para `~/.hermes`.
    public static func hermesHomeDirectory() -> URL {
        if let home = environmentValue("HERMES_HOME") {
            return URL(fileURLWithPath: home, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".hermes", isDirectory: true)
    }

    /// Arquivo `.env` do Hermes, de onde a chave `OPENROUTER_API_KEY` pode ser aproveitada.
    public static func hermesEnvironmentFileURL() -> URL {
        hermesHomeDirectory().appendingPathComponent(".env")
    }

    /// Banco de estado do Hermes, com o histórico local de consumo.
    public static func hermesStateDatabaseURL() -> URL {
        hermesHomeDirectory().appendingPathComponent("state.db")
    }

    /// Lê uma variável de ambiente descartando valores vazios (que não configuram nada).
    static func environmentValue(_ name: String) -> String? {
        guard let value = ProcessInfo.processInfo.environment[name],
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return value
    }
}
