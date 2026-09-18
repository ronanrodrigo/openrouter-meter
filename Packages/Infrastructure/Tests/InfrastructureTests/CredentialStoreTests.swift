import Application
import Domain
import Foundation
@testable import Infrastructure
import Testing

/// Escreve um arquivo temporário com o conteúdo informado.
private func makeFile(_ contents: String, name: String = "hermes.env") throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(UUID().uuidString)-\(name)")
    try contents.write(to: url, atomically: true, encoding: .utf8)
    return url
}

@Suite("HermesEnvironmentCredentialStore")
struct HermesEnvironmentCredentialStoreTests {
    @Test("lê OPENROUTER_API_KEY do arquivo .env")
    func readsKey() async throws {
        let url = try makeFile("""
        # ambiente do Hermes
        export HERMES_HOME=~/.hermes

        OPENROUTER_API_KEY=sk-or-v1-exemplo
        OUTRA_CHAVE=ignorada
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let store = HermesEnvironmentCredentialStore(envFilePath: url)
        #expect(await store.credential() == "sk-or-v1-exemplo")
    }

    @Test("aceita aspas simples e duplas ao redor do valor")
    func readsQuotedValues() async throws {
        let doubleQuoted = try makeFile("OPENROUTER_API_KEY=\"sk-or-v1-aspas\"\n")
        let singleQuoted = try makeFile("OPENROUTER_API_KEY='sk-or-v1-simples'\n")
        defer {
            try? FileManager.default.removeItem(at: doubleQuoted)
            try? FileManager.default.removeItem(at: singleQuoted)
        }

        #expect(await HermesEnvironmentCredentialStore(envFilePath: doubleQuoted).credential() == "sk-or-v1-aspas")
        #expect(await HermesEnvironmentCredentialStore(envFilePath: singleQuoted).credential() == "sk-or-v1-simples")
    }

    @Test("arquivo ausente devolve nil")
    func missingFile() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ausente-\(UUID().uuidString).env")
        let store = HermesEnvironmentCredentialStore(envFilePath: url)

        #expect(await store.credential() == nil)
    }

    @Test("chave ausente ou vazia devolve nil")
    func missingKey() async throws {
        let url = try makeFile("OUTRA_CHAVE=algo\nOPENROUTER_API_KEY=\n")
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(await HermesEnvironmentCredentialStore(envFilePath: url).credential() == nil)
    }

    @Test("parsing ignora comentários e espaços")
    func parsingRules() {
        let contents = """
        # comentário
        export   OPENROUTER_API_KEY =  sk-or-v1-espacos
        """
        #expect(HermesEnvironmentCredentialStore.value(for: "OPENROUTER_API_KEY", in: contents) == "sk-or-v1-espacos")
    }

    @Test("gravação é recusada e limpeza é vazia")
    func writeIsRefused() async throws {
        let url = try makeFile("OPENROUTER_API_KEY=sk-or-v1-exemplo\n")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = HermesEnvironmentCredentialStore(envFilePath: url)
        let thrown = await #expect(throws: UsageError.self) {
            try await store.save("sk-or-v1-nova")
        }
        guard let thrown, case .unavailable = thrown else {
            Issue.record("esperava unavailable, veio \(String(describing: thrown))")
            return
        }

        await store.clear()
        #expect(await store.credential() == "sk-or-v1-exemplo")
    }
}

@Suite("KeychainCredentialStore")
struct KeychainCredentialStoreTests {
    @Test("sem item gravado devolve nil, sem lançar erro")
    func missingItem() async {
        // Serviço aleatório: garante que nenhum item real do usuário seja tocado.
        let store = KeychainCredentialStore(service: "dev.ronanrodrigo.OpenRouterMeter.testes.\(UUID().uuidString)")

        #expect(await store.credential() == nil)
    }

    @Test("limpeza de item inexistente é silenciosa")
    func clearingIsSilent() async {
        let store = KeychainCredentialStore(service: "dev.ronanrodrigo.OpenRouterMeter.testes.\(UUID().uuidString)")

        await store.clear()
        #expect(await store.credential() == nil)
    }

    @Test("grava, lê de volta, atualiza e remove, em serviço isolado")
    func roundTrip() async throws {
        // Serviço aleatório: o item criado aqui nunca colide com o do aplicativo em execução
        // e é removido no fim do teste.
        let service = "dev.ronanrodrigo.OpenRouterMeter.testes.\(UUID().uuidString)"
        let store = KeychainCredentialStore(service: service)

        // Primeira gravação: o item não existe, então o caminho é o de inserção.
        try await store.save("chave-1")
        #expect(await store.credential() == "chave-1")

        // Segunda gravação: o item já existe, então o caminho é o de atualização.
        try await store.save("chave-2")
        #expect(await store.credential() == "chave-2")

        await store.clear()
        #expect(await store.credential() == nil)
    }
}
