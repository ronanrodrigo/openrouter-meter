import AppKit
import Application
import Domain
import Foundation
import Infrastructure
@testable import OpenRouterMeter
import SwiftUI
import Testing

// Harness de renderização das views, usado por `ViewRenderingTests`.
//
// Não é teste de regra de negócio: desenha a view de verdade, em claro e em escuro, e exige
// resultado não vazio. O PNG de cada caso fica em `build/renders/` para inspeção humana.

/// Resultado de um render: bitmap, PNG codificado e escala usada.
struct Render {
    let image: CGImage
    let png: Data
    let scale: CGFloat

    /// Largura em pontos (pixels divididos pela escala).
    var width: CGFloat {
        CGFloat(image.width) / scale
    }

    /// Altura em pontos.
    var height: CGFloat {
        CGFloat(image.height) / scale
    }

    var byteCount: Int {
        png.count
    }

    /// Cores distintas amostradas em grade esparsa — zero ou uma cor significa render em branco.
    func distinctColors(step: Int = 7) -> Int {
        guard let data = image.dataProvider?.data as Data? else { return 0 }
        let bytesPerPixel = max(1, image.bitsPerPixel / 8)
        let bytesPerRow = image.bytesPerRow
        var seen = Set<UInt32>()
        for row in stride(from: 0, to: image.height, by: step) {
            for column in stride(from: 0, to: image.width, by: step) {
                let offset = row * bytesPerRow + column * bytesPerPixel
                guard offset + 3 < data.count else { continue }
                let pixel = UInt32(data[offset]) << 24
                    | UInt32(data[offset + 1]) << 16
                    | UInt32(data[offset + 2]) << 8
                    | UInt32(data[offset + 3])
                seen.insert(pixel)
            }
        }
        return seen.count
    }
}

enum RenderError: Error {
    case emptyImage
    case encodingFailed
}

/// Raiz do repositório, derivada da posição deste arquivo: `<repo>/OpenRouterMeter/Tests/`.
var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

var artifactsDirectory: URL {
    repositoryRoot.appending(path: "build/renders")
}

var docsImagesDirectory: URL {
    repositoryRoot.appending(path: "docs/images")
}

/// Fundo opaco do sistema já resolvido na aparência pedida.
///
/// `NSColor.windowBackgroundColor` é dinâmico. Resolvido na aparência corrente, com conversão
/// para sRGB, o `Color(nsColor:)` deixa de ser reavaliado na hora do desenho — sem isso o
/// render escuro sairia com fundo claro e texto claro, branco no branco.
@MainActor
func backgroundColor(for scheme: ColorScheme) -> NSColor {
    guard let appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua) else {
        return .windowBackgroundColor
    }
    var resolved: NSColor = .windowBackgroundColor
    appearance.performAsCurrentDrawingAppearance {
        resolved = NSColor.windowBackgroundColor.usingColorSpace(.sRGB) ?? NSColor.windowBackgroundColor
    }
    return resolved
}

/// Renderiza de verdade, na aparência pedida.
///
/// Caminho principal: `ImageRenderer`, que desenha o corpo SwiftUI direto no bitmap.
/// `ImageRenderer` tem dois buracos conhecidos que o harness trata: o fundo vindo de
/// aparência do sistema sai branco em escuro, e contêineres respaldados por AppKit (o `Form`
/// de Ajustes, botões e `ProgressView`) não se achatam — as duas coisas aparecem como render
/// em branco. Nesse caso o harness redesenha a hierarquia de verdade com `NSHostingView` na
/// aparência pedida, que é o caminho que o app usa em execução.
@MainActor
func renderView(_ view: some View, scheme: ColorScheme, frame: CGSize? = nil,
                hosted: Bool = false) throws -> Render {
    let previous = NSApp.appearance
    NSApp.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
    defer { NSApp.appearance = previous }

    let content = view
        .environment(\.colorScheme, scheme)
        .background(Color(nsColor: backgroundColor(for: scheme)))
        .frame(width: frame?.width, height: frame?.height, alignment: .top)

    if !hosted, let image = try imageFromRenderer(content) {
        return image
    }
    return try renderHosted(content, frame: frame)
}

/// Render pelo `ImageRenderer`; `nil` quando ele devolve uma imagem de uma cor só.
@MainActor
func imageFromRenderer(_ content: some View) throws -> Render? {
    let renderer = ImageRenderer(content: content)
    renderer.scale = 2
    renderer.isOpaque = true

    guard let image = renderer.cgImage else { throw RenderError.emptyImage }
    let render = try Render(image: image, png: encode(image), scale: renderer.scale)
    return render.distinctColors() >= 2 ? render : nil
}

/// Redesenha a hierarquia AppKit de verdade, na aparência corrente.
@MainActor
func renderHosted(_ content: some View, frame: CGSize?) throws -> Render {
    let hosting = NSHostingView(rootView: content)
    hosting.appearance = NSApp.appearance
    hosting.layoutSubtreeIfNeeded()

    let fitting = hosting.fittingSize
    let scale = NSScreen.main?.backingScaleFactor ?? 2
    let size = frame ?? fitting
    hosting.frame = NSRect(origin: .zero, size: size)
    hosting.layoutSubtreeIfNeeded()

    let pixels = CGSize(width: max(size.width, 1) * scale, height: max(size.height, 1) * scale)
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(pixels.width.rounded()),
        pixelsHigh: Int(pixels.height.rounded()),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw RenderError.emptyImage
    }
    representation.size = size
    hosting.cacheDisplay(in: hosting.bounds, to: representation)
    guard let image = representation.cgImage else { throw RenderError.emptyImage }
    return try Render(image: image, png: encode(image), scale: scale)
}

func encode(_ image: CGImage) throws -> Data {
    guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        throw RenderError.encodingFailed
    }
    return png
}

@discardableResult
func write(_ render: Render, named name: String, in directory: URL) throws -> URL {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appending(path: "\(name).png")
    try render.png.write(to: url)
    return url
}

/// Desenha, grava o PNG e exige que o resultado não seja branco e tenha a medida esperada.
@MainActor
@discardableResult
func checkRender(
    _ name: String,
    _ view: some View,
    scheme: ColorScheme,
    width: CGFloat? = nil,
    height: CGFloat? = nil,
    frame: CGSize? = nil,
    hosted: Bool = false
) throws -> Render {
    let render = try renderView(view, scheme: scheme, frame: frame, hosted: hosted)
    let suffix = scheme == .dark ? "escuro" : "claro"
    let url = try write(render, named: "\(name)-\(suffix)", in: artifactsDirectory)

    #expect(render.byteCount > 800, "\(name) [\(suffix)]: PNG com \(render.byteCount) bytes em \(url.path)")
    #expect(render.distinctColors() >= 3, "\(name) [\(suffix)]: render em branco")

    if let width {
        #expect(render.width == width, "\(name) [\(suffix)]: largura \(render.width)pt, esperada \(width)pt")
    }
    if let height {
        #expect(render.height == height, "\(name) [\(suffix)]: altura \(render.height)pt, esperada \(height)pt")
    }
    return render
}

/// Largura do painel com o respiro interno, como nos previews das views.
@MainActor
func canvas(_ view: some View, width: CGFloat = Theme.Metrics.panelWidth) -> some View {
    view
        .padding(Theme.Metrics.panelPadding)
        .frame(width: width, alignment: .topLeading)
}

// MARK: - Dublês dos estados do view model

/// Gateway de crédito que sempre falha — monta o estado de falha sem tocar a rede.
struct FailingCreditsGateway: CreditsGateway {
    let error: UsageError

    func accountSnapshot() async throws -> AccountSnapshot {
        throw error
    }
}

@MainActor
func loadedViewModel() async -> UsageViewModel {
    let viewModel = UsageViewModel.preview()
    await viewModel.refresh()
    return viewModel
}

@MainActor
func failedViewModel() async -> UsageViewModel {
    let composition = CompositionRoot(
        credits: FailingCreditsGateway(error: .unauthorized),
        usage: SampleUsageGateway(),
        credentialStore: InMemoryCredentialStore()
    )
    let viewModel = UsageViewModel(
        composition: composition,
        defaults: UserDefaults(suiteName: "dev.ronanrodrigo.OpenRouterMeter.rendering") ?? .standard
    )
    await viewModel.refresh()
    return viewModel
}
