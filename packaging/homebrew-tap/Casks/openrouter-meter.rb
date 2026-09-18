cask "openrouter-meter" do
  version "__VERSION__"
  sha256 "__SHA256__"

  url "https://github.com/ronanrodrigo/openrouter-meter/releases/download/v#{version}/OpenRouterMeter-#{version}.zip"
  name "OpenRouter Meter"
  desc "Saldo e consumo da conta do OpenRouter na barra de menus"
  homepage "https://github.com/ronanrodrigo/openrouter-meter"

  depends_on macos: :sequoia

  app "OpenRouterMeter.app"

  # O app é assinado de forma ad-hoc, sem notarização. O Homebrew 7 aplica quarentena
  # em todo cask baixado e não tem mais a flag --no-quarantine, então removemos o
  # atributo com.apple.quarantine da app instalada para o Gatekeeper não bloquear.
  postflight_steps do
    run "/usr/bin/xattr",
        args: ["-dr", "com.apple.quarantine", "{{appdir}}/OpenRouterMeter.app"]
  end

  uninstall quit: "dev.ronanrodrigo.OpenRouterMeter"

  zap trash: [
    "~/Library/Preferences/dev.ronanrodrigo.OpenRouterMeter.plist",
    "~/Library/Saved Application State/dev.ronanrodrigo.OpenRouterMeter.savedState",
  ]

  caveats <<~EOS
    O OpenRouter Meter é um item da barra de menus (LSUIElement): ele não abre janela
    nem aparece no Dock. Procure o ícone na barra de menus depois de abrir o app.

    Este app não é notarizado (assinatura ad-hoc). O cask já remove o atributo
    com.apple.quarantine da app instalada, então o Gatekeeper não bloqueia a abertura.
  EOS
end
