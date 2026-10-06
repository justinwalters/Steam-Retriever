import AppKit

let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let rect = NSRect(x: s * 0.06, y: s * 0.06, width: s * 0.88, height: s * 0.88)
    let body = NSBezierPath(roundedRect: rect, xRadius: s * 0.2, yRadius: s * 0.2)
    NSGradient(colors: [NSColor(red: 0.30, green: 0.55, blue: 1.0, alpha: 1),
                        NSColor(red: 0.07, green: 0.10, blue: 0.22, alpha: 1)])!.draw(in: body, angle: -65)
    let ring = NSBezierPath(ovalIn: NSRect(x: s * 0.23, y: s * 0.23, width: s * 0.54, height: s * 0.54))
    ring.lineWidth = s * 0.035
    NSColor.white.withAlphaComponent(0.92).setStroke()
    ring.stroke()
    let tri = NSBezierPath()
    tri.move(to: NSPoint(x: s * 0.43, y: s * 0.36))
    tri.line(to: NSPoint(x: s * 0.43, y: s * 0.64))
    tri.line(to: NSPoint(x: s * 0.66, y: s * 0.50))
    tri.close()
    NSColor.white.setFill()
    tri.fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let sizes: [(String, Int)] = [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64),
                              ("128x128", 128), ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512),
                              ("512x512", 512), ("512x512@2x", 1024)]
for (name, px) in sizes {
    try? render(px).write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}
