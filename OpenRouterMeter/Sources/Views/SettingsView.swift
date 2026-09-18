import AppKit
import Domain
import SwiftUI

/// Janela de ajustes: chave da API, o que mostrar na barra e a cadência de atualização.
struct SettingsView: View {
    @Bindable var viewModel: UsageViewModel

    @State private var credentialDraft = ""

    var body: some View {
        Form {
            Section {
                SecureField("sk-or-v1-…", text: $credentialDraft)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: Theme.Spacing.xs) {
                    Button("Salvar") {
                        let value = credentialDraft
                        credentialDraft = ""
                        Task { await viewModel.saveCredential(value) }
                    }
                    .disabled(credentialDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Remover") {
                        Task { await viewModel.removeCredential() }
                    }
                    .disabled(!viewModel.hasStoredCredential)

                    Spacer(minLength: 0)
                }
            } header: {
                Text("Chave da API da OpenRouter")
            } footer: {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("A chave fica no Keychain.")
                    Text("Sem chave salva, o aplicativo usa ~/.hermes/.env e o histórico local do Hermes.")
                }
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Section("Barra de menus") {
                Picker("Mostrar na barra", selection: $viewModel.menuBarDisplayMode) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            }

            Section("Atualização") {
                Picker("Atualizar a cada", selection: $viewModel.refreshInterval) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text(interval.title).tag(interval)
                    }
                }

                LabeledContent("Última atualização", value: lastRefreshText)
            }
        }
        .formStyle(.grouped)
        .frame(width: Theme.Metrics.settingsWidth)
        .onAppear { NSApplication.shared.activate() }
    }

    private var lastRefreshText: String {
        guard let lastRefresh = viewModel.lastRefresh else { return "Nunca atualizado" }
        return Formatters.relativeTime(since: lastRefresh)
    }
}

#Preview("Ajustes") {
    SettingsView(viewModel: .preview())
}
