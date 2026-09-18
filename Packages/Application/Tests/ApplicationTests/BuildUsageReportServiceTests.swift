@testable import Application
import Domain
import Testing

private struct CreditsStub: CreditsGateway {
    let result: Result<AccountSnapshot, UsageError>

    func accountSnapshot() async throws -> AccountSnapshot {
        switch result {
        case let .success(snapshot): return snapshot
        case let .failure(error): throw error
        }
    }
}

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

@Suite("BuildUsageReportService")
struct BuildUsageReportServiceTests {
    private let instant = UnixTimestamp(seconds: 1_789_694_711)

    private func service(
        credits: Result<AccountSnapshot, UsageError> = .success(Doubles.snapshot()),
        usage: Result<[UsageWindow], UsageError> = .success([Doubles.window(.today), Doubles.window(.lastSevenDays)]),
        source: UsageSource = .localHermes
    ) -> BuildUsageReportService {
        BuildUsageReportService(
            credits: CreditsStub(result: credits),
            usage: UsageStub(source: source, result: usage),
            now: { instant }
        )
    }

    @Test("monta o relatório com saldo, janelas, origem e instante")
    func happyPath() async throws {
        let report = try await service().execute()
        #expect(report.account.remaining == Money(dollars: 91.9))
        #expect(report.windows.count == 2)
        #expect(report.source == .localHermes)
        #expect(report.capturedAt == instant)
    }

    @Test("propaga a origem da fonte de consumo")
    func propagatesSource() async throws {
        let report = try await service(source: .accountActivity).execute()
        #expect(report.source == .accountActivity)
    }

    @Test("saldo é obrigatório: falha derruba o relatório")
    func creditsFailureThrows() async {
        let failing = service(credits: .failure(.unauthorized))
        await #expect(throws: UsageError.unauthorized) {
            _ = try await failing.execute()
        }
    }

    @Test("detalhamento é opcional: falha encolhe o relatório em vez de derrubá-lo")
    func usageFailureDegrades() async throws {
        let report = try await service(usage: .failure(.network("offline"))).execute()
        #expect(report.windows.isEmpty)
        #expect(report.account.remaining == Money(dollars: 91.9))
    }
}
