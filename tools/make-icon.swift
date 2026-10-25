// Draws the app icon and writes AppIcon.icns. Run: swift tools/make-icon.swift
import AppKit

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px) / 1024

    // macOS icon grid: 824pt rounded square centered in 1024, with a soft drop shadow.
    let tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let path = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowOffset = NSSize(width: 0, height: -10 * s)
    shadow.shadowBlurRadius = 24 * s
    shadow.set()
    NSColor.white.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: NSColor(srgbRed: 1.00, green: 0.84, blue: 0.38, alpha: 1),
               ending: NSColor(srgbRed: 0.98, green: 0.62, blue: 0.16, alpha: 1))!.draw(in: path, angle: -90)

    // Paper sheet with ruled lines.
    let sheet = NSRect(x: 262 * s, y: 222 * s, width: 500 * s, height: 580 * s)
    NSGraphicsContext.saveGraphicsState()
    let sheetShadow = NSShadow()
    sheetShadow.shadowColor = NSColor(srgbRed: 0.6, green: 0.3, blue: 0, alpha: 0.35)
    sheetShadow.shadowOffset = NSSize(width: 0, height: -8 * s)
    sheetShadow.shadowBlurRadius = 20 * s
    sheetShadow.set()
    NSColor.white.setFill()
    NSBezierPath(roundedRect: sheet, xRadius: 48 * s, yRadius: 48 * s).fill()
    NSGraphicsContext.restoreGraphicsState()

    let widths: [CGFloat] = [300, 364, 280, 340, 200]
    for (i, w) in widths.enumerated() {
        let y = (680 - CGFloat(i) * 92) * s
        let color = i == 0 ? NSColor(srgbRed: 0.98, green: 0.62, blue: 0.16, alpha: 1)
                           : NSColor(white: 0.82, alpha: 1)
        color.setFill()
        NSBezierPath(roundedRect: NSRect(x: 330 * s, y: y, width: w * s, height: 34 * s),
                     xRadius: 17 * s, yRadius: 17 * s).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try! render(size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try! render(size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("AppIcon.icns").path]
try! task.run()
task.waitUntilExit()
try! render(1024).write(to: FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon-preview.png"))
print("Wrote AppIcon.icns")
