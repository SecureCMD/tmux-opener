// Post-processes raw window captures for the README:
//   • rounds the corners and adds a drop shadow to every <name>-<light|dark>.png
//   • builds hero-<light|dark>.png (main window + editor on a gradient backdrop)
// Usage: swift scripts/compose_hero.swift <dir>
import AppKit

let dir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/images")

func load(_ name: String) -> CGImage? {
    guard let img = NSImage(contentsOf: dir.appendingPathComponent(name)) else { return nil }
    return img.cgImage(forProposedRect: nil, context: nil, hints: nil)
}

func write(_ image: CGImage, _ name: String) {
    let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
    try! data.write(to: dir.appendingPathComponent(name))
}

func context(_ w: Int, _ h: Int) -> CGContext {
    CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpace(name: CGColorSpace.sRGB)!,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

let radius: CGFloat = 32

/// Draws a window image with rounded corners, a hairline border and a shadow.
func drawWindow(_ img: CGImage, in ctx: CGContext, at origin: CGPoint, dark: Bool, shadow: CGFloat = 1) {
    let rect = CGRect(origin: origin, size: CGSize(width: img.width, height: img.height))
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -24 * shadow), blur: 70 * shadow,
                  color: CGColor(gray: 0, alpha: dark ? 0.55 : 0.30))
    ctx.addPath(path)
    ctx.setFillColor(CGColor(gray: dark ? 0.15 : 1, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.draw(img, in: rect)
    ctx.restoreGState()

    ctx.addPath(path)
    ctx.setStrokeColor(CGColor(gray: dark ? 1 : 0, alpha: dark ? 0.18 : 0.14))
    ctx.setLineWidth(2)
    ctx.strokePath()
}

func framed(_ img: CGImage, dark: Bool) -> CGImage {
    let pad = 110
    let ctx = context(img.width + pad * 2, img.height + pad * 2)
    drawWindow(img, in: ctx, at: CGPoint(x: pad, y: pad + 20), dark: dark)
    return ctx.makeImage()!
}

for appearance in ["light", "dark"] {
    let dark = appearance == "dark"
    guard let main = load("main-\(appearance).png") else { continue }
    let editor = load("editor-\(appearance).png")

    // Hero: gradient card with the main window and the editor overlapping it.
    let w = main.width + 520, h = main.height + 340
    let ctx = context(w, h)
    let bg = CGRect(x: 0, y: 0, width: w, height: h)
    ctx.addPath(CGPath(roundedRect: bg, cornerWidth: 56, cornerHeight: 56, transform: nil))
    ctx.clip()
    let colors = dark
        ? [CGColor(srgbRed: 0.18, green: 0.20, blue: 0.38, alpha: 1), CGColor(srgbRed: 0.04, green: 0.05, blue: 0.10, alpha: 1)]
        : [CGColor(srgbRed: 0.80, green: 0.82, blue: 1.00, alpha: 1), CGColor(srgbRed: 0.78, green: 0.95, blue: 0.92, alpha: 1)]
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: CGFloat(h)), end: CGPoint(x: CGFloat(w), y: 0), options: [])

    drawWindow(main, in: ctx, at: CGPoint(x: 120, y: h - main.height - 120), dark: dark)
    if let editor {
        let scale: CGFloat = 0.82
        let ew = Int(CGFloat(editor.width) * scale), eh = Int(CGFloat(editor.height) * scale)
        let small = context(ew, eh)
        small.interpolationQuality = .high
        small.draw(editor, in: CGRect(x: 0, y: 0, width: ew, height: eh))
        drawWindow(small.makeImage()!, in: ctx, at: CGPoint(x: w - ew - 110, y: 90), dark: dark, shadow: 1.3)
    }
    write(ctx.makeImage()!, "hero-\(appearance).png")

    for name in ["main", "editor", "settings"] {
        if let img = load("\(name)-\(appearance).png") {
            write(framed(img, dark: dark), "\(name)-\(appearance).png")
        }
    }
}
print("Composed images in \(dir.path)")
