// Renders Assets/logo.svg into AppIcon.icns and PNGs for the website.
// Usage: swift Assets/make_icon.swift   (run from the Keytone folder)
import AppKit

let svg = URL(fileURLWithPath: "Assets/logo.svg")
guard let image = NSImage(contentsOf: svg) else { fatalError("cannot read logo.svg") }

func png(_ size: Int, to url: URL) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: "Assets/AppIcon.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for s in [16, 32, 128, 256, 512] {
    png(s, to: iconset.appendingPathComponent("icon_\(s)x\(s).png"))
    png(s * 2, to: iconset.appendingPathComponent("icon_\(s)x\(s)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", "AppIcon.icns"]
try! p.run(); p.waitUntilExit()
try? fm.removeItem(at: iconset)

try? fm.createDirectory(at: URL(fileURLWithPath: "docs/assets"), withIntermediateDirectories: true)
png(512, to: URL(fileURLWithPath: "docs/assets/icon-512.png"))
png(180, to: URL(fileURLWithPath: "docs/assets/apple-touch-icon.png"))
png(64, to: URL(fileURLWithPath: "docs/assets/favicon.png"))
print("AppIcon.icns + docs/assets/*.png written")
