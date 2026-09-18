import Domain
import Foundation
@testable import OpenRouterMeter
import Testing

/// Contrato dos dados de amostra.
///
/// Os valores do `PreviewData` alimentam os previews do Xcode, o harness de renderização das
/// views e as imagens de documentação. Se eles mudarem de forma incoerente — uma janela que
/// não bate com a origem, um relatório sem janelas — o que aparece na tela deixa de ser o que
/// os testes de renderização mostram, e o defeito passa despercebido.
@Suite("PreviewData")
struct PreviewDataTests {
    @Test("a conta de amostra tem saldo, consumo e cota gratuita coerentes")
    func account() {
        let account = PreviewData.account

        #expect(account.remaining == account.totalCredits - account.totalUsage)
        #expect(account.totalCredits > account.totalUsage)
        #expect(account.freeModelQuota?.limit == 1000)
    }

    @Test("cada janela de amostra traz os seus modelos")
    func windows() {
        #expect(PreviewData.todayWindow.kind == .today)
        #expect(PreviewData.weekWindow.kind == .lastSevenDays)
        #expect(!PreviewData.todayWindow.models.isEmpty)
        #expect(!PreviewData.weekWindow.models.isEmpty)

        // Os modelos vêm ordenados por tokens de entrada, e a participação soma 1.
        let window = PreviewData.todayWindow
        let shares = window.rankedModels.map(window.share(of:))
        #expect(shares == shares.sorted(by: >))
        #expect(abs(shares.reduce(0, +) - 1) < 0.0001)
    }

    @Test("o relatório de amostra usa a atividade da conta com as duas janelas")
    func report() {
        let report = PreviewData.report

        #expect(report.source == .accountActivity)
        #expect(report.window(.today) != nil)
        #expect(report.window(.lastSevenDays) != nil)
        #expect(report.account == PreviewData.account)
    }

    @Test("o relatório sem chave usa só o histórico local, sem janelas")
    func reportWithoutKey() {
        let report = PreviewData.reportWithoutKey

        #expect(report.source == .localHermes)
        #expect(report.windows.isEmpty)
        #expect(report.window(.today) == nil)
    }
}
