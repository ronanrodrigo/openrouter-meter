import AppKit
import Domain
import SwiftUI

/// Painel exibido ao clicar no ícone da barra de menus.
struct MenuBarPanelView: View {
    var viewModel: UsageViewModel

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            PanelHeaderView(
                title: "OpenRouter Meter",
                source: viewModel.sourceLabel,
                isRefreshing: viewModel.isRefreshing
            )

            content

            Divider()

            StatusFooterView(
                lastRefresh: viewModel.lastRefresh,
                isRefreshing: viewModel.isRefreshing,
                onRefresh: { Task { await viewModel.refresh() } },
                onSettings: openSettings,
                onQuit: { NSApplication.shared.terminate(nil) }
            )
        }
        .padding(Theme.Metrics.panelPadding)
        .frame(width: Theme.Metrics.panelWidth)
        .task { await viewModel.refreshOnOpen() }
    }

    @ViewBuilder
    private var content: some View {
        if let report = viewModel.report {
            BalanceHeaderView(account: report.account)
            windowCards(for: report)
            if let message = viewModel.errorMessage {
                NoticeView(message: message, actionTitle: "Abrir Ajustes", action: openSettings)
            }
        } else if let message = viewModel.errorMessage {
            NoticeView(message: message, actionTitle: "Abrir Ajustes", action: openSettings)
        } else {
            LoadingView()
        }
    }

    private func windowCards(for report: UsageReport) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ForEach(UsageWindowKind.allCases) { kind in
                if let window = report.window(kind) {
                    UsageWindowCard(window: window)
                }
            }
        }
    }

    private func openSettings() {
        NSApplication.shared.activate()
        openWindow(id: OpenRouterMeterApp.settingsWindowID)
    }
}

#Preview("Painel") {
    MenuBarPanelView(viewModel: .preview())
}
