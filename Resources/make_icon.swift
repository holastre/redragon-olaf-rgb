import AppKit
import CoreGraphics

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func renderIcon(pixelSize: Int, path: String) {
    let size = CGFloat(pixelSize)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    let rect = CGRect(x: size * 0.06, y: size * 0.06, width: size * 0.88, height: size * 0.88)
    let corner = size * 0.21
    let bgPath = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)

    // Dark obsidian rounded background
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    let bgColors = [
        NSColor(calibratedRed: 0.14, green: 0.14, blue: 0.19, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.06, green: 0.06, blue: 0.09, alpha: 1).cgColor
    ] as CFArray
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bgColors, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

    // RGB neon border glow inside
    let rainbowColors = [
        NSColor(calibratedRed: 1.0, green: 0.15, blue: 0.30, alpha: 0.95).cgColor,
        NSColor(calibratedRed: 1.0, green: 0.65, blue: 0.0, alpha: 0.95).cgColor,
        NSColor(calibratedRed: 0.0, green: 0.92, blue: 0.65, alpha: 0.95).cgColor,
        NSColor(calibratedRed: 0.10, green: 0.55, blue: 1.0, alpha: 0.95).cgColor,
        NSColor(calibratedRed: 0.72, green: 0.20, blue: 1.0, alpha: 0.95).cgColor
    ] as CFArray
    let rGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: rainbowColors, locations: [0, 0.25, 0.5, 0.75, 1.0])!

    // Stylized glowing 3x5 keycaps grid
    let cols = 5
    let rows = 3
    let padX = size * 0.18
    let padY = size * 0.27
    let gap = size * 0.032
    let gridW = size - padX * 2
    let gridH = size - padY * 2
    let keyW = (gridW - gap * CGFloat(cols - 1)) / CGFloat(cols)
    let keyH = (gridH - gap * CGFloat(rows - 1)) / CGFloat(rows)

    for r in 0..<rows {
        for c in 0..<cols {
            // Bottom row: wide spacebar in the middle
            if r == 0 && (c == 2 || c == 3) { continue }
            var kw = keyW
            if r == 0 && c == 1 {
                kw = keyW * 3 + gap * 2
            }
            let kx = padX + CGFloat(c) * (keyW + gap)
            let ky = padY + CGFloat(r) * (keyH + gap)
            let kRect = CGRect(x: kx, y: ky, width: kw, height: keyH)
            let kPath = CGPath(roundedRect: kRect, cornerWidth: size * 0.035, cornerHeight: size * 0.035, transform: nil)

            let hue = CGFloat(c) / CGFloat(cols) * 0.8 + CGFloat(r) * 0.08
            let kColor = NSColor(calibratedHue: hue.truncatingRemainder(dividingBy: 1.0), saturation: 0.92, brightness: 1.0, alpha: 1.0)

            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: size * 0.045, color: kColor.withAlphaComponent(0.85).cgColor)
            ctx.addPath(kPath)
            ctx.setFillColor(kColor.withAlphaComponent(0.28).cgColor)
            ctx.fillPath()
            ctx.restoreGState()

            ctx.addPath(kPath)
            ctx.setStrokeColor(kColor.cgColor)
            ctx.setLineWidth(max(1.0, size * 0.018))
            ctx.strokePath()
        }
    }

    // Bottom RGB underglow bar
    let barRect = CGRect(x: size * 0.18, y: size * 0.15, width: size * 0.64, height: size * 0.045)
    let barPath = CGPath(roundedRect: barRect, cornerWidth: barRect.height / 2, cornerHeight: barRect.height / 2, transform: nil)
    ctx.saveGState()
    ctx.addPath(barPath)
    ctx.clip()
    ctx.drawLinearGradient(rGrad, start: CGPoint(x: barRect.minX, y: 0), end: CGPoint(x: barRect.maxX, y: 0), options: [])
    ctx.restoreGState()

    ctx.restoreGState()

    // Outer subtle metallic border
    ctx.addPath(bgPath)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.18).cgColor)
    ctx.setLineWidth(max(1.0, size * 0.014))
    ctx.strokePath()

    NSGraphicsContext.restoreGraphicsState()

    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: path))
}

let sizes: [(String, Int)] = [
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

for (name, px) in sizes {
    renderIcon(pixelSize: px, path: "\(outDir)/\(name)")
}
print("Generated iconset in \(outDir)")
