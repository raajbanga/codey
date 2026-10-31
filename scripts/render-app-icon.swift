// Renders the three 1024 px app-icon PNGs (light, dark, tinted) into the
// AppIcon.appiconset. macOS only:
//   swift scripts/render-app-icon.swift codey/Resources/Assets.xcassets/AppIcon.appiconset
import SwiftUI
import AppKit

// Mirrors AppGlyph: "chevron.left.forwardslash.chevron.right", semibold SF
// Pro, 40% of the tile (Sprint 3 "pastel ink" facelift, S9). The system masks the corners, so tiles are full-bleed.
struct Icon: View {
    let background: Color
    let glyph: Color
    var body: some View {
        ZStack {
            background
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 1024 * 0.40, weight: .semibold))
                .foregroundStyle(glyph)
        }
        .frame(width: 1024, height: 1024)
    }
}

func hex(_ v: UInt32) -> Color {
    Color(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
}

@MainActor func write(_ view: Icon, _ path: String) {
    let renderer = ImageRenderer(content: view)
    renderer.scale = 1
    guard let cg = renderer.cgImage else { fatalError("render failed") }
    // Opaque RGB PNG (App Store icons must not have alpha).
    let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    print("wrote", path)
}

let out = CommandLine.arguments[1]
MainActor.assumeIsolated {
    // Light: the loading-screen tile (BrandFill #CFDCEB, OnBrandFill ink glyph #1F3350).
    write(Icon(background: hex(0xCFDCEB), glyph: hex(0x1F3350)), out + "/icon-1024.png")
    // Dark: the dark paper surface (#141518), glyph in the dark-mode brand ink (#A9C0DD).
    write(Icon(background: hex(0x141518), glyph: hex(0xA9C0DD)), out + "/icon-1024-dark.png")
    // Tinted: grayscale; iOS tints by luminance, so a white glyph on black.
    write(Icon(background: .black, glyph: .white), out + "/icon-1024-tinted.png")
}
