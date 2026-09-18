/// Falhas estáveis de domínio, traduzidas na fronteira de infraestrutura.
///
/// Um adaptador nunca deixa erro de SDK, de HTTP ou de SQLite vazar para a aplicação.
public enum UsageError: Error, Sendable, Equatable {
    /// Sem credencial utilizável.
    case missingCredential
    /// Credencial recusada pelo provedor.
    case unauthorized
    /// Limite de requisições do provedor.
    case rateLimited
    /// Falha de rede ou de transporte.
    case network(String)
    /// Resposta fora do contrato esperado.
    case invalidResponse(String)
    /// A capacidade não está disponível para esta configuração.
    case unavailable(String)
}
