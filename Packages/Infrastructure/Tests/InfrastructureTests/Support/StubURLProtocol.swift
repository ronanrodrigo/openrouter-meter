import Foundation
import Synchronization

/// Resposta simulada devolvida pelo `StubURLProtocol`.
enum StubResponse: Sendable {
    /// Resposta HTTP com status e corpo controlados pelo teste.
    case http(status: Int, body: Data)
    /// Falha de transporte, como um `URLError` de rede indisponível.
    case failure(URLError)
}

/// Intercepta requisições de uma `URLSession` de teste, sem tocar a rede.
///
/// Cada teste registra o seu próprio manipulador e recebe uma URL base com um token único no
/// caminho. O `StubURLProtocol` resolve a resposta pelo token, e não por um manipulador
/// global, de modo que testes executados em paralelo pelo Swift Testing não interferem entre
/// si. O estado compartilhado vive em `Mutex`, sem `@unchecked Sendable`.
final class StubURLProtocol: URLProtocol {
    private typealias Handler = @Sendable (URLRequest) -> StubResponse

    private static let handlers = Mutex<[String: Handler]>([:])
    private static let received = Mutex<[String: [URLRequest]]>([:])

    /// Registra um manipulador e devolve a URL base tokenizada que o aciona.
    static func makeBaseURL(_ handler: @escaping @Sendable (URLRequest) -> StubResponse) -> URL {
        let token = UUID().uuidString
        handlers.withLock { $0[token] = handler }
        received.withLock { $0[token] = [] }
        return URL(string: "https://openrouter.test/\(token)/api/v1")
            ?? URL(fileURLWithPath: "/")
    }

    /// Resposta JSON a partir de um texto literal.
    static func json(_ text: String, status: Int = 200) -> StubResponse {
        .http(status: status, body: Data(text.utf8))
    }

    /// Requisições observadas para a URL base informada, na ordem em que chegaram.
    static func requests(for baseURL: URL) -> [URLRequest] {
        guard let token = token(in: baseURL) else { return [] }
        return received.withLock { $0[token] ?? [] }
    }

    /// Sessão efêmera cujas requisições passam por este protocolo.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    /// Extrai o token do primeiro segmento do caminho da URL base.
    private static func token(in url: URL) -> String? {
        url.pathComponents.dropFirst().first
    }

    // MARK: - URLProtocol

    // URLProtocol exige sobrescrever métodos de classe (`canInit`, `canonicalRequest`),
    // que não podem ser `static`: a exceção à regra é da API do sistema, não do nosso código.
    // swiftlint:disable static_over_final_class

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    // swiftlint:enable static_over_final_class

    override func startLoading() {
        guard let url = request.url,
              let token = Self.token(in: url),
              let handler = Self.handlers.withLock({ $0[token] })
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        Self.received.withLock { $0[token, default: []].append(request) }

        switch handler(request) {
        case let .failure(error):
            client?.urlProtocol(self, didFailWithError: error)

        case let .http(status, body):
            guard let response = HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
