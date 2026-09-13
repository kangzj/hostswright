import AppKit

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: a) }
let space = CGColorSpaceCreateDeviceRGB()

func render(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let s = size
    let inset = s * 0.0625
    let rect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let radius = rect.width * 0.2237
    let squircle = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let w = rect.width

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.035, color: CGColor(gray: 0, alpha: 0.4))
    ctx.addPath(squircle); ctx.setFillColor(rgb(0.03, 0.20, 0.24)); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(squircle); ctx.clip()
    let base = CGGradient(colorsSpace: space, colors: [rgb(0.03, 0.20, 0.24), rgb(0.05, 0.50, 0.48), rgb(0.35, 0.85, 0.70)] as CFArray, locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(base, start: CGPoint(x: rect.minX, y: rect.minY), end: CGPoint(x: rect.maxX, y: rect.maxY), options: [])
    let bloom = CGGradient(colorsSpace: space, colors: [rgb(0.65, 1, 0.85, 0.55), rgb(0.4, 0.95, 0.75, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(bloom, startCenter: CGPoint(x: rect.maxX * 0.82, y: rect.maxY * 0.88), startRadius: 0, endCenter: CGPoint(x: rect.maxX * 0.82, y: rect.maxY * 0.88), endRadius: rect.width * 0.75, options: [])
    let vignette = CGGradient(colorsSpace: space, colors: [rgb(0, 0, 0, 0), rgb(0, 0.1, 0.1, 0.35)] as CFArray, locations: [0.55, 1])!
    ctx.drawRadialGradient(vignette, startCenter: center, startRadius: 0, endCenter: center, endRadius: rect.width * 0.78, options: [])

    let pillX = rect.minX + w * 0.19
    let pillW = w * 0.30
    let pillH = w * 0.13
    let nodeX = rect.minX + w * 0.74
    let nodeR = w * 0.075
    let lineW = w * 0.055
    let ringW = w * 0.04
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.03, color: rgb(0, 0.12, 0.12, 0.45))
    for (offset, on) in [(1, true), (0, false), (-1, true)] {
        let y = center.y + CGFloat(offset) * w * 0.24
        let row = CGMutablePath()
        row.addRoundedRect(in: CGRect(x: pillX, y: y - pillH / 2, width: pillW, height: pillH), cornerWidth: pillH / 2, cornerHeight: pillH / 2)
        row.addRect(CGRect(x: pillX + pillW / 2, y: y - lineW / 2, width: nodeX - nodeR - pillX - pillW / 2, height: lineW))
        ctx.setFillColor(rgb(1, 1, 1, on ? 1 : 0.45)); ctx.addPath(row); ctx.fillPath()
        ctx.setFillColor(rgb(1, 1, 1)); ctx.setStrokeColor(rgb(1, 1, 1))
        if on {
            ctx.addEllipse(in: CGRect(x: nodeX - nodeR, y: y - nodeR, width: nodeR * 2, height: nodeR * 2)); ctx.fillPath()
        } else {
            ctx.setLineWidth(ringW)
            let r = nodeR - ringW / 2
            ctx.addEllipse(in: CGRect(x: nodeX - r, y: y - r, width: r * 2, height: r * 2)); ctx.strokePath()
        }
    }
    ctx.restoreGState()

    let sheen = CGGradient(colorsSpace: space, colors: [rgb(1, 1, 1, 0.16), rgb(1, 1, 1, 0.0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(sheen, start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.midX, y: rect.midY), options: [])
    ctx.restoreGState()

    ctx.addPath(squircle); ctx.setStrokeColor(rgb(1, 1, 1, 0.12)); ctx.setLineWidth(max(1, s * 0.004)); ctx.strokePath()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let out = CommandLine.arguments[1]
for (name, px) in [("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64), ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512), ("icon_512x512", 512), ("icon_512x512@2x", 1024)] {
    try! render(size: CGFloat(px)).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
}
