import AppKit
import Domain
import Foundation
import SwiftUI

/// Aplicativo de barra de menus: nenhuma janela principal, apenas o painel do ícone e a
/// janela de ajustes.
@main
struct OpenRouterMeterApp: App {
    /// Identificador da janela de ajustes.
    static let settingsWindowID = "settings"

    @State private var viewModel: UsageViewModel

    init() {
        let model = UsageViewModel()
        _viewModel = State(initialValue: model)
        Task { await model.start() }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanelView(viewModel: viewModel)
        } label: {
            MenuBarTitleLabel(title: viewModel.menuBarTitle)
        }
        .menuBarExtraStyle(.window)

        Window("Ajustes", id: Self.settingsWindowID) {
            SettingsView(viewModel: viewModel)
        }
        .windowResizability(.contentSize)
    }
}

/// Conteúdo do item da barra de menus: ícone do sistema e o valor escolhido.
private struct MenuBarTitleLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            Image(systemName: "gauge.medium")
            Text(title)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("OpenRouter Meter")
        .accessibilityValue(title)
    }
}
