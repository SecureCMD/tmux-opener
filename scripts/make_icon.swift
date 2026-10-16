// Draws the app icon with CoreGraphics and writes an .iconset folder.
// Usage: swift scripts/make_icon.swift <output.iconset>
import AppKit

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

func render(px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let s = CGFloat(px) / 1024
    func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: x * s, y: y * s, width: w * s, height: h * s)
    }

    // Squircle background (macOS icon grid: 824 px out of 1024).
    let base = r(100, 100, 824, 824)
    let shape = NSBezierPath(roundedRect: base, xRadius: 185 * s, yRadius: 185 * s)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * s), blur: 28 * s,
                  color: NSColor.black.withAlphaComponent(0.35).cgColor)
    color(0x101326).setFill()
    shape.fill()
    ctx.restoreGState()

    ctx.saveGState()
    shape.addClip()
    NSGradient(colors: [color(0x2E3360), color(0x161A33), color(0x0B0D1A)])!
        .draw(in: base, angle: -90)
    // Soft highlight at the top.
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.10), NSColor.white.withAlphaComponent(0)])!
        .draw(in: r(100, 600, 824, 324), angle: -90)

    // Window buttons.
    for (i, c) in [0xFF5F57, 0xFEBC2E, 0x28C840].enumerated() {
        color(UInt32(c)).setFill()
        NSBezierPath(ovalIn: r(178 + CGFloat(i) * 52, 790, 34, 34)).fill()
    }

    let green = color(0x3DDC97)
    let teal = color(0x7AA2F7)

    // tmux panes.
    func pane(_ rect: CGRect, active: Bool) {
        let p = NSBezierPath(roundedRect: rect, xRadius: 26 * s, yRadius: 26 * s)
        (active ? green.withAlphaComponent(0.10) : NSColor.white.withAlphaComponent(0.05)).setFill()
        p.fill()
        (active ? green : teal.withAlphaComponent(0.55)).setStroke()
        p.lineWidth = (active ? 7 : 5) * s
        p.stroke()
    }
    pane(r(170, 270, 360, 480), active: true)
    pane(r(554, 520, 300, 230), active: false)
    pane(r(554, 270, 300, 226), active: false)

    // "❯_" prompt in the active pane.
    let chevron = NSBezierPath()
    chevron.move(to: CGPoint(x: 225 * s, y: 690 * s))
    chevron.line(to: CGPoint(x: 285 * s, y: 645 * s))
    chevron.line(to: CGPoint(x: 225 * s, y: 600 * s))
    chevron.lineWidth = 22 * s
    chevron.lineCapStyle = .round
    chevron.lineJoinStyle = .round
    green.setStroke()
    chevron.stroke()
    green.setFill()
    NSBezierPath(roundedRect: r(315, 592, 95, 22), xRadius: 6 * s, yRadius: 6 * s).fill()

    // Placeholder "text" lines in the other panes.
    NSColor.white.withAlphaComponent(0.30).setFill()
    for (x, y, w) in [(590, 690, 180), (590, 650, 120), (590, 610, 200), (590, 440, 150), (590, 400, 210), (590, 360, 100)] {
        NSBezierPath(roundedRect: r(CGFloat(x), CGFloat(y), CGFloat(w), 16), xRadius: 8 * s, yRadius: 8 * s).fill()
    }
    NSColor.white.withAlphaComponent(0.18).setFill()
    for (x, y, w) in [(225, 520, 220), (225, 480, 160), (225, 440, 250), (225, 400, 120)] {
        NSBezierPath(roundedRect: r(CGFloat(x), CGFloat(y), CGFloat(w), 16), xRadius: 8 * s, yRadius: 8 * s).fill()
    }

    // tmux status bar.
    green.setFill()
    NSBezierPath(roundedRect: r(170, 175, 684, 58), xRadius: 16 * s, yRadius: 16 * s).fill()
    color(0x0B0D1A, 0.85).setFill()
    NSBezierPath(roundedRect: r(190, 190, 90, 28), xRadius: 8 * s, yRadius: 8 * s).fill()
    color(0x0B0D1A, 0.45).setFill()
    NSBezierPath(roundedRect: r(295, 190, 90, 28), xRadius: 8 * s, yRadius: 8 * s).fill()
    NSBezierPath(roundedRect: r(704, 190, 130, 28), xRadius: 8 * s, yRadius: 8 * s).fill()

    ctx.restoreGState()

    // Hairline border.
    NSColor.white.withAlphaComponent(0.12).setStroke()
    shape.lineWidth = 2 * s
    shape.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try render(px: size).write(to: out.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(px: size * 2).write(to: out.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
print("Icon written to \(out.path)")
