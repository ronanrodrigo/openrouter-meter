@testable import Application
import Domain
import Foundation
import Testing

private struct UsageStub: UsageGateway {
    let source: UsageSource
    let result: Result<[UsageWindow], UsageError>

    func windows(now: UnixTimestamp) async throws -> [UsageWindow] {
        switch result {
        case let .success(windows): return windows
        case let .failure(error): throw error
        }
    }
}

@Suite("FallbackUsageGateway")
struct FallbackUsageGatewayTests {
    private let instant = UnixTimestamp(seconds: 0)

    @Test("usa a fonte primária quando ela responde")
    func prefersPrimary() async throws {
        let gateway = FallbackUsageGateway(
            primary: UsageStub(source: .accountActivity, result: .success([Doubles.window(.today, input: 7)])),
            secondary: UsageStub(source: .localHermes, result: .success([Doubles.window(.today, input: 1)]))
        )
        let windows = try await gateway.windows(now: instant)
        #expect(windows.first?.tokens.input == 7)
        #expect(gateway.source == .accountActivity)
    }

    @Test("cai para a fonte secundária quando a primária falha")
    func fallsBack() async throws {
        let gateway = FallbackUsageGateway(
            primary: UsageStub(source: .accountActivity, result: .failure(.unavailable("sem chave de provisioning"))),
            secondary: UsageStub(source: .localHermes, result: .success([Doubles.window(.today, input: 3)]))
        )
        let windows = try await gateway.windows(now: instant)
        #expect(windows.first?.tokens.input == 3)
    }

    @Test("propaga o erro quando as duas fontes falham")
    func bothFail() async {
        let gateway = FallbackUsageGateway(
            primary: UsageStub(source: .accountActivity, result: .failure(.unavailable("x"))),
            secondary: UsageStub(source: .localHermes, result: .failure(.network("offline")))
        )
        await #expect(throws: UsageError.network("offline")) {
            _ = try await gateway.windows(now: instant)
        }
    }
}

private final class CredentialBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?
    private(set) var saveCount = 0
    private(set) var clearCount = 0

    init(value: String?) {
        self.value = value
    }

    func read() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func write(_ newValue: String?) {
        lock.lock()
        defer { lock.unlock() }
        value = newValue
    }

    func recordSave() {
        lock.lock()
        defer { lock.unlock() }
        saveCount += 1
    }

    func recordClear() {
        lock.lock()
        defer { lock.unlock() }
        clearCount += 1
    }
}

private struct CredentialStub: CredentialStore {
    let box: CredentialBox
    let failsOnSave: Bool

    init(box: CredentialBox, failsOnSave: Bool = false) {
        self.box = box
        self.failsOnSave = failsOnSave
    }

    func credential() async -> String? {
        box.read()
    }

    func save(_ credential: String) async throws {
        if failsOnSave {
            throw UsageError.unavailable("somente leitura")
        }
        box.write(credential)
        box.recordSave()
    }

    func clear() async {
        box.write(nil)
        box.recordClear()
    }
}

@Suite("FirstAvailableCredentialStore")
struct FirstAvailableCredentialStoreTests {
    @Test("usa a credencial primária quando existe")
    func prefersPrimary() async {
        let store = FirstAvailableCredentialStore(
            primary: CredentialStub(box: CredentialBox(value: "do-keychain")),
            secondary: CredentialStub(box: CredentialBox(value: "do-ambiente"))
        )
        #expect(await store.credential() == "do-keychain")
    }

    @Test("cai para a fonte secundária quando a primária é vazia")
    func usesSecondary() async {
        let store = FirstAvailableCredentialStore(
            primary: CredentialStub(box: CredentialBox(value: nil)),
            secondary: CredentialStub(box: CredentialBox(value: "do-ambiente"))
        )
        #expect(await store.credential() == "do-ambiente")
    }

    @Test("devolve nulo quando nenhuma fonte tem credencial")
    func noCredential() async {
        let store = FirstAvailableCredentialStore(
            primary: CredentialStub(box: CredentialBox(value: nil)),
            secondary: CredentialStub(box: CredentialBox(value: nil))
        )
        #expect(await store.credential() == nil)
    }

    @Test("grava e limpa apenas na fonte primária")
    func writesToPrimary() async throws {
        let primary = CredentialBox(value: nil)
        let secondary = CredentialBox(value: "antiga")
        let store = FirstAvailableCredentialStore(
            primary: CredentialStub(box: primary),
            secondary: CredentialStub(box: secondary)
        )

        try await store.save("nova")
        #expect(primary.read() == "nova")
        #expect(secondary.read() == "antiga")
        #expect(primary.saveCount == 1)

        await store.clear()
        #expect(primary.read() == nil)
        #expect(primary.clearCount == 1)
    }

    @Test("propaga a falha de gravação da fonte somente leitura")
    func saveFailurePropagates() async {
        let store = FirstAvailableCredentialStore(
            primary: CredentialStub(box: CredentialBox(value: nil), failsOnSave: true),
            secondary: CredentialStub(box: CredentialBox(value: nil))
        )
        await #expect(throws: UsageError.unavailable("somente leitura")) {
            try await store.save("nova")
        }
    }
}
