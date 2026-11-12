// Renders the Molekit app icon (the "m" tunnel mark) into Assets/Molekit.icns.
// Run: swift Scripts/make-icon.swift
import AppKit

func render(size: CGFloat) -> Data {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.translateBy(x: 0, y: size); ctx.scaleBy(x: 1, y: -1) // y down, like the SVG

    // macOS icon grid: 824/1024 body with rounded corners
    let inset = size * 100 / 1024
    let body = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = body.width * 0.225
    let path = CGPath(roundedRect: body, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // soft drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.012), blur: size * 0.03, color: NSColor.black.withAlphaComponent(0.45).cgColor)
    ctx.addPath(path); ctx.setFillColor(NSColor.black.cgColor); ctx.fillPath()
    ctx.restoreGState()

    // dark glossy tile
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let tile = CGGradient(colorsSpace: space, colors: [
        CGColor(srgbRed: 0x1C/255, green: 0x2A/255, blue: 0x44/255, alpha: 1),
        CGColor(srgbRed: 0x0B/255, green: 0x14/255, blue: 0x24/255, alpha: 1)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(tile, start: CGPoint(x: 0, y: body.minY), end: CGPoint(x: 0, y: body.maxY), options: [])
    // cyan glow from the top right
    let glow = CGGradient(colorsSpace: space, colors: [
        CGColor(srgbRed: 0.25, green: 0.88, blue: 1, alpha: 0.28),
        CGColor(srgbRed: 0.25, green: 0.88, blue: 1, alpha: 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: body.maxX * 0.85, y: body.minY), startRadius: 0,
                           endCenter: CGPoint(x: body.maxX * 0.85, y: body.minY), endRadius: body.width * 0.9, options: [])
    // top highlight edge
    ctx.addPath(path)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.16).cgColor)
    ctx.setLineWidth(size * 0.006)
    ctx.strokePath()
    ctx.restoreGState()

    // the mark, 64-unit design scaled into the tile
    let markSize = body.width * 0.62
    let s = markSize / 64
    let ox = body.midX - markSize / 2, oy = body.midY - markSize / 2 - body.width * 0.02
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }
    let mark = CGMutablePath()
    mark.move(to: p(10, 50)); mark.addLine(to: p(10, 30))
    mark.addArc(center: p(18, 30), radius: 8 * s, startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
    mark.addLine(to: p(26, 50))
    mark.move(to: p(26, 30))
    mark.addArc(center: p(34, 30), radius: 8 * s, startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
    mark.addLine(to: p(42, 44))
    mark.addArc(center: p(48, 44), radius: 6 * s, startAngle: .pi, endAngle: 0, clockwise: true)
    let cyan = CGColor(srgbRed: 0x40/255, green: 0xE0/255, blue: 1, alpha: 1)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: size * 0.035, color: CGColor(srgbRed: 0.25, green: 0.88, blue: 1, alpha: 0.6))
    ctx.addPath(mark)
    ctx.setStrokeColor(cyan); ctx.setLineWidth(7 * s); ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.strokePath()
    ctx.setFillColor(cyan)
    ctx.fillEllipse(in: CGRect(x: ox + 49 * s, y: oy + 31 * s, width: 10 * s, height: 10 * s))
    ctx.restoreGState()

    image.unlockFocus()
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: "Assets/Molekit.iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try render(size: CGFloat(base)).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(size: CGFloat(base * 2)).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try render(size: 1024).write(to: URL(fileURLWithPath: "Assets/icon-1024.png"))
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", "Assets/Molekit.icns"]
try task.run(); task.waitUntilExit()
try? fm.removeItem(at: iconset)
print(task.terminationStatus == 0 ? "Assets/Molekit.icns written" : "iconutil failed")
