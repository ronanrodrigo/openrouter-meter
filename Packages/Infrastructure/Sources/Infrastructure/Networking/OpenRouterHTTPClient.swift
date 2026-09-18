import Domain
import Foundation

/// Cliente HTTP mínimo da API do OpenRouter, com tradução de erro na fronteira.
///
/// Nenhum `URLError`, erro de `URLSession` ou status HTTP cru escapa daqui: toda falha é
/// convertida em `UsageError`, que é o vocabulário estável do domínio.
struct OpenRouterHTTPClient: Sendable {
    let baseURL: URL
    let apiKey: String
    let session: URLSession

    /// Executa um `GET` autenticado e devolve o corpo da resposta.
    ///
    /// - Parameter forbiddenMeansUnavailable: quando `true`, um `403` é reportado como
    ///   `UsageError.unavailable` em vez de `unauthorized`. É o caso de `/activity`, que
    ///   exige chave de provisioning: a ausência dela não invalida a credencial, apenas
    ///   torna o endpoint inutilizável e libera o fallback para o histórico local.
    func get(_ path: String, forbiddenMeansUnavailable: Bool = false) async throws -> Data {
        guard let url = URL(string: baseURL.absoluteString + "/" + path) else {
            throw UsageError.invalidResponse("caminho inválido: \(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw UsageError.network(error.localizedDescription)
        } catch {
            throw UsageError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw UsageError.invalidResponse("resposta não-HTTP em \(path)")
        }

        switch http.statusCode {
        case 200 ... 299:
            return data
        case 401:
            throw UsageError.unauthorized
        case 403:
            throw forbiddenMeansUnavailable
                ? UsageError.unavailable("endpoint \(path) exige chave de provisioning")
                : UsageError.unauthorized
        case 429:
            throw UsageError.rateLimited
        default:
            throw UsageError.invalidResponse("HTTP \(http.statusCode) em \(path)")
        }
    }

    /// Decodifica um corpo JSON, convertendo qualquer falha em `UsageError.invalidResponse`.
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw UsageError.invalidResponse("corpo inesperado: \(error)")
        }
    }
}
