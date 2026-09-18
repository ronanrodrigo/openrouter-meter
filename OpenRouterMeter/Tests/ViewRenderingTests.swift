import AppKit
import Domain
import Foundation
@testable import OpenRouterMeter
import SwiftUI
import Testing

// Harness de renderização das views, não teste de regra de negócio.
//
// Cada caso desenha a view de verdade com `ImageRenderer`, em claro e em escuro, com os dados
// determinísticos do `PreviewData` interno. O que isto pega: view que quebra ao montar, medida
// errada e render em branco (uma cor só). O PNG de cada caso fica em `build/renders/` para
// inspeção humana; os dois do painel também vão para `docs/images/`, usados pelo README e pela
// landing page. A mecânica do desenho está em `RenderHarness.swift`.

@MainActor
@Suite("Renderização das views", .serialized)
struct ViewRenderingTests {
    @Test("ModelBreakdownView desenha com e sem modelos")
    func modelBreakdown() throws {
        let window = PreviewData.todayWindow
        try checkRender(
            "model-breakdown-com-modelos",
            canvas(ModelBreakdownView(models: window.rankedModels) { window.share(of: $0) }),
            scheme: .light
        )
        try checkRender(
            "model-breakdown-sem-modelos",
            canvas(ModelBreakdownView(models: []) { _ in 0 }),
            scheme: .light
        )
    }

    @Test("StatusFooterView desenha em repouso e atualizando")
    func statusFooter() throws {
        for scheme in [ColorScheme.light, .dark] {
            let idle = StatusFooterView(
                lastRefresh: Date().addingTimeInterval(-240),
                isRefreshing: false,
                onRefresh: {},
                onSettings: {},
                onQuit: {}
            )
            let refreshing = StatusFooterView(
                lastRefresh: nil,
                isRefreshing: true,
                onRefresh: {},
                onSettings: {},
                onQuit: {}
            )
            try checkRender("rodape-repouso", canvas(idle), scheme: scheme)
            try checkRender("rodape-atualizando", canvas(refreshing), scheme: scheme)
        }
    }

    @Test("PanelHeaderView, NoticeView e LoadingView desenham")
    func panelComponents() throws {
        for scheme in [ColorScheme.light, .dark] {
            let header = PanelHeaderView(
                title: "OpenRouter Meter",
                source: "Atividade da conta",
                isRefreshing: false
            )
            let headerRefreshing = PanelHeaderView(title: "OpenRouter Meter", source: nil, isRefreshing: true)
            let notice = NoticeView(
                message: OpenRouterMeterPreviewMessages.unauthorized,
                actionTitle: "Abrir Ajustes",
                action: {}
            )
            try checkRender("cabecalho-com-origem", canvas(header), scheme: scheme)
            try checkRender("cabecalho-atualizando", canvas(headerRefreshing), scheme: scheme)
            try checkRender("aviso", canvas(notice), scheme: scheme)
            try checkRender("carregando", canvas(LoadingView()), scheme: scheme)
        }
    }

    @Test("MeterBar cobre accent, atenção, crítico e fino")
    func meterBar() throws {
        let bars: [(String, MeterBar)] = [
            ("medidor-accent", MeterBar(fraction: 0.32, label: "Consumo", valueText: "32%")),
            ("medidor-atencao", MeterBar(fraction: 0.78, tone: .state, label: "Consumo", valueText: "78%")),
            ("medidor-critico", MeterBar(fraction: 0.94, tone: .state, label: "Consumo", valueText: "94%")),
            (
                "medidor-fino",
                MeterBar(
                    fraction: 0.5,
                    height: Theme.Metrics.thinMeterHeight,
                    label: "Participação",
                    valueText: "50%"
                )
            ),
        ]
        for (name, bar) in bars {
            for scheme in [ColorScheme.light, .dark] {
                try checkRender(name, canvas(bar.frame(width: 180)), scheme: scheme, width: Theme.Metrics.panelWidth)
            }
        }
    }

    @Test("BalanceHeaderView desenha com e sem cota gratuita")
    func balanceHeader() throws {
        let withoutQuota = AccountSnapshot(
            totalCredits: Money(dollars: 100),
            totalUsage: Money(dollars: 94.20),
            isFreeTier: true,
            freeModelQuota: nil
        )
        for scheme in [ColorScheme.light, .dark] {
            try checkRender("saldo-com-cota", canvas(BalanceHeaderView(account: PreviewData.account)), scheme: scheme)
            try checkRender("saldo-sem-cota", canvas(BalanceHeaderView(account: withoutQuota)), scheme: scheme)
        }
    }

    @Test("UsageWindowCard desenha hoje e sete dias")
    func usageWindowCard() throws {
        for scheme in [ColorScheme.light, .dark] {
            try checkRender("janela-hoje", canvas(UsageWindowCard(window: PreviewData.todayWindow)), scheme: scheme)
            try checkRender("janela-sete-dias", canvas(UsageWindowCard(window: PreviewData.weekWindow)), scheme: scheme)
        }
    }

    @Test("SettingsView desenha em claro e em escuro")
    func settings() async throws {
        let viewModel = await loadedViewModel()
        for scheme in [ColorScheme.light, .dark] {
            try checkRender(
                "ajustes",
                SettingsView(viewModel: viewModel),
                scheme: scheme,
                width: Theme.Metrics.settingsWidth,
                hosted: true
            )
        }
    }

    @Test("MenuBarPanelView desenha lido, em falha e lendo")
    func menuBarPanel() async throws {
        let loaded = await loadedViewModel()
        try checkRender("painel-lido", MenuBarPanelView(viewModel: loaded), scheme: .light)
        try checkRender("painel-lido", MenuBarPanelView(viewModel: loaded), scheme: .dark)

        let failed = await failedViewModel()
        try checkRender("painel-falha", MenuBarPanelView(viewModel: failed), scheme: .light)

        // Sem refresh: `ImageRenderer` não dispara o `.task` do painel, então fica o estado de leitura.
        let reading = UsageViewModel.preview()
        try checkRender("painel-lendo", MenuBarPanelView(viewModel: reading), scheme: .light)
    }

    @Test("painel carregado vira as imagens de docs")
    func documentationImages() async throws {
        // Caminho AppKit: é o que o app usa em execução, e é o único que desenha os botões do
        // rodapé e o recorte exato do painel. Sem `frame`: o painel se dimensiona sozinho.
        let light = try await renderView(MenuBarPanelView(viewModel: loadedViewModel()), scheme: .light, hosted: true)
        let dark = try await renderView(MenuBarPanelView(viewModel: loadedViewModel()), scheme: .dark, hosted: true)

        #expect(light.width == Theme.Metrics.panelWidth)
        #expect(dark.width == Theme.Metrics.panelWidth)
        #expect(light.height == dark.height)
        #expect(light.height > 400)
        #expect(light.byteCount > 800)
        #expect(dark.byteCount > 800)
        #expect(light.distinctColors() >= 3)
        #expect(dark.distinctColors() >= 3)
        // Claro e escuro não podem sair idênticos, senão a aparência não chegou ao render.
        #expect(light.png != dark.png, "renders de claro e escuro saíram iguais")
        // Nada de PNG gigante: o recorte é exato, sem margem extra.
        #expect(light.byteCount < 1_000_000, "PNG claro com \(light.byteCount) bytes")
        #expect(dark.byteCount < 1_000_000, "PNG escuro com \(dark.byteCount) bytes")

        try write(light, named: "painel-claro", in: docsImagesDirectory)
        try write(dark, named: "painel-escuro", in: docsImagesDirectory)
    }
}
