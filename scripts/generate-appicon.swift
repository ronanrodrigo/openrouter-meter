#!/usr/bin/env swift
//
//  generate-appicon.swift
//  OpenRouter Meter
//
//  Desenha o ícone do app e escreve todos os PNGs exigidos pelo asset catalog
//  do macOS (AppIcon.appiconset).
//
//  Uso:
//      swift scripts/generate-appicon.swift <destino>
//
//  Exemplo:
//      swift scripts/generate-appicon.swift OpenRouterMeter/Sources/Resources/Assets.xcassets/AppIcon.appiconset
//
//  Características:
//   * Autocontido: só AppKit / CoreGraphics / ImageIO / Foundation.
//   * Determinístico: mesma entrada => bytes idênticos (sem datas, sem aleatoriedade).
//   * Re-executável: sobrescreve os PNGs, sempre a partir do mesmo desenho mestre 1024x1024.
//   * Desenha UMA vez em 1024x1024 e reduz com interpolação de alta qualidade
//     para cada tamanho (nunca desenha por tamanho).
//

import AppKit
import CoreGraphics
import Foundation
import ImageIO

// MARK: - Parâmetros de desenho

/// Lado do desenho mestre. Todos os tamanhos saem deste, por redução.
let masterSide = 1024

/// Grade oficial de ícones do macOS: dentro de um canvas de 1024, a "squircle"
/// ocupa 824x824 (margem de ~9,8% em cada lado), com canto ~22,4% do lado.
let squircleInset: CGFloat = 100
let squircleSide: CGFloat = .init(masterSide) - squircleInset * 2 // 824

/// Expoente da superelipse. 5.0 é o "squircle" da Apple (cantos contínuos,
/// bem mais suaves que um simples rounded rect).
let squircleExponent: CGFloat = 5.0

/// Cor de acento de dados (#80A269 — verde-sálvia).
let accent = (r: CGFloat(0x80) / 255, g: CGFloat(0xA2) / 255, b: CGFloat(0x69) / 255)

/// Glifo: branco levemente amortecido, sem sombra.
let glyphWhite: CGFloat = 0.97

// MARK: - Utilidades

func srgbColor(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

func grayscale(_ v: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: v, green: v, blue: v, alpha: a)
}

/// Mistura linear de duas componentes (t em 0 => a, t em 1 => b).
func mix(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
    a + (b - a) * t
}

/// Path de superelipse (squircle) inscrito em `rect`.
func squirclePath(in rect: CGRect, exponent n: CGFloat, segments: Int = 1024) -> CGPath {
    let path = CGMutablePath()
    let a = rect.width / 2
    let b = rect.height / 2
    let cx = rect.midX
    let cy = rect.midY
    let e = 2 / n

    for i in 0 ... segments {
        let t = CGFloat(i) / CGFloat(segments) * 2 * .pi
        let ct = cos(t)
        let st = sin(t)
        let x = cx + a * (ct < 0 ? -1 : 1) * pow(abs(ct), e)
        let y = cy + b * (st < 0 ? -1 : 1) * pow(abs(st), e)
        let p = CGPoint(x: x, y: y)
        if i == 0 {
            path.move(to: p)
        } else {
            path.addLine(to: p)
        }
    }
    path.closeSubpath()
    return path
}

func makeContext(side: Int) -> CGContext {
    guard let ctx = CGContext(
        data: nil,
        width: side,
        height: side,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        FileHandle.standardError.write(Data("erro: não foi possível criar o CGContext\n".utf8))
        exit(1)
    }
    ctx.setShouldAntialias(true)
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high
    return ctx
}

// MARK: - Desenho mestre (1024x1024)

/// Desenha o ícone completo num contexto quadrado de lado `masterSide`.
func drawIcon(into ctx: CGContext) {
    let side = CGFloat(masterSide)
    let squircleRect = CGRect(
        x: squircleInset,
        y: squircleInset,
        width: squircleSide,
        height: squircleSide
    )

    // --- Fundo: squircle com gradiente vertical sutil (topo claro, base escura)
    let path = squirclePath(in: squircleRect, exponent: squircleExponent)

    let top = accent
    let bottom = accent
    let topColor = srgbColor(
        mix(top.r, 1.0, 0.20),
        mix(top.g, 1.0, 0.20),
        mix(top.b, 1.0, 0.20)
    )
    let bottomColor = srgbColor(
        mix(bottom.r, 0.0, 0.20),
        mix(bottom.g, 0.0, 0.20),
        mix(bottom.b, 0.0, 0.20)
    )

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        colors: [topColor, bottomColor] as CFArray,
        locations: [0.0, 1.0]
    )!
    // eixo y do CoreGraphics é para cima: começa no topo (claro) e termina na base (escuro).
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: side),
        end: CGPoint(x: 0, y: 0),
        options: []
    )
    ctx.restoreGState()

    // --- Glifo: medidor / velocímetro minimalista, branco, sem sombra
    let cx = squircleRect.midX
    // O arco abre para baixo, então a massa visual fica deslocada para cima;
    // compensa-se descendo o centro para equilibrar opticamente dentro do squircle.
    let cy = squircleRect.midY - squircleSide * 0.075
    let center = CGPoint(x: cx, y: cy)

    let R = squircleSide * 0.295 // raio do arco principal
    let arcWidth = squircleSide * 0.100 // espessura do arco
    let startAngle: CGFloat = 205 * .pi / 180
    let endAngle: CGFloat = -25 * .pi / 180

    let white = grayscale(glyphWhite)

    // Arco do medidor
    ctx.saveGState()
    ctx.setStrokeColor(white)
    ctx.setLineWidth(arcWidth)
    ctx.setLineCap(.round)
    ctx.beginPath()
    ctx.addArc(center: center, radius: R, startAngle: startAngle, endAngle: endAngle, clockwise: true)
    ctx.strokePath()
    ctx.restoreGState()

    // "with dots": pequenos pontos ao redor do arco, recuados das pontas
    // (10° de folga em cada lado) para não colidirem com os caps arredondados.
    let dotCount = 9
    let dotRing = R * 1.24
    let dotRadius = squircleSide * 0.022
    let dotPad: CGFloat = 10 * .pi / 180
    ctx.saveGState()
    ctx.setFillColor(white)
    for i in 0 ..< dotCount {
        let f = CGFloat(i) / CGFloat(dotCount - 1)
        let angle = (startAngle - dotPad) + ((endAngle + dotPad) - (startAngle - dotPad)) * f
        let p = CGPoint(x: center.x + dotRing * cos(angle), y: center.y + dotRing * sin(angle))
        ctx.fillEllipse(in: CGRect(
            x: p.x - dotRadius,
            y: p.y - dotRadius,
            width: dotRadius * 2,
            height: dotRadius * 2
        ))
    }
    ctx.restoreGState()

    // Ponteiro em 50% (apontando para cima, no meio do arco 205°..-25°)
    ctx.saveGState()
    ctx.setStrokeColor(white)
    ctx.setLineWidth(squircleSide * 0.055)
    ctx.setLineCap(.round)
    ctx.beginPath()
    ctx.move(to: center)
    ctx.addLine(to: CGPoint(x: center.x, y: center.y + R * 0.72))
    ctx.strokePath()
    ctx.restoreGState()

    // Cubo central do ponteiro
    let hubRadius = squircleSide * 0.075
    ctx.saveGState()
    ctx.setFillColor(white)
    ctx.fillEllipse(in: CGRect(
        x: center.x - hubRadius,
        y: center.y - hubRadius,
        width: hubRadius * 2,
        height: hubRadius * 2
    ))
    ctx.restoreGState()
}

/// Desenho mestre, já rasterizado em 1024x1024.
func renderMaster() -> CGImage {
    let ctx = makeContext(side: masterSide)
    drawIcon(into: ctx)
    guard let image = ctx.makeImage() else {
        FileHandle.standardError.write(Data("erro: não foi possível rasterizar o desenho mestre\n".utf8))
        exit(1)
    }
    return image
}

// MARK: - Redimensionamento + escrita

/// Reduz o desenho mestre para `side` x `side` com interpolação de alta qualidade.
func resample(_ master: CGImage, to side: Int) -> CGImage {
    if side == masterSide {
        return master
    }
    let ctx = makeContext(side: side)
    ctx.interpolationQuality = .high
    ctx.draw(master, in: CGRect(x: 0, y: 0, width: side, height: side))
    guard let image = ctx.makeImage() else {
        FileHandle.standardError.write(Data("erro: falha ao redimensionar para \(side)px\n".utf8))
        exit(1)
    }
    return image
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(
        url as CFURL,
        "public.png" as CFString,
        1,
        nil
    ) else {
        FileHandle.standardError.write(Data("erro: não foi possível criar o destino PNG \(url.path)\n".utf8))
        exit(1)
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        FileHandle.standardError.write(Data("erro: falha ao escrever \(url.path)\n".utf8))
        exit(1)
    }
}

// MARK: - Saída

/// Nomes e tamanhos em pixels exigidos pelo AppIcon.appiconset do macOS.
let outputs: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

// MARK: - Entry point

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data(
        "uso: swift scripts/generate-appicon.swift <destino AppIcon.appiconset>\n".utf8
    ))
    exit(2)
}

let destination = URL(fileURLWithPath: args[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

let master = renderMaster()

// cache: vários nomes compartilham o mesmo tamanho em pixels (ex.: 32 = 16@2x = 32@1x)
var cache: [Int: CGImage] = [:]
for output in outputs {
    let image: CGImage
    if let cached = cache[output.pixels] {
        image = cached
    } else {
        image = resample(master, to: output.pixels)
        cache[output.pixels] = image
    }
    writePNG(image, to: destination.appendingPathComponent(output.name))
    print("gerado \(output.name) (\(output.pixels)x\(output.pixels))")
}

print("ok: \(outputs.count) PNGs escritos em \(destination.path)")
