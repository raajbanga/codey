import SwiftUI
import AppKit

// Mirrors AppGlyph: "chevron.left.forwardslash.chevron.right", bold rounded,
// 42% of the tile. The system masks the corners, so tiles are full-bleed.
struct Icon: View {
    let background: Color
    let glyph: Color
    var body: some View {
        ZStack {
            background
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 1024 * 0.42, weight: .bold, design: .rounded))
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
    // Light: the loading-screen tile (BrandFill light #4F4FE8, white glyph).
    write(Icon(background: hex(0x4F4FE8), glyph: .white), out + "/icon-1024.png")
    // Dark: near-black indigo tile, glyph in the dark-mode brand (D13 #8C8CFF).
    write(Icon(background: hex(0x14142B), glyph: hex(0x8C8CFF)), out + "/icon-1024-dark.png")
    // Tinted: grayscale; iOS tints by luminance, so a white glyph on black.
    write(Icon(background: .black, glyph: .white), out + "/icon-1024-tinted.png")
}
