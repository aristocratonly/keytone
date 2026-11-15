// Procedural rubber-stamp impression mask for the site's Download stamp.
// White = ink, transparent = void. Ink is heaviest at the rim, the interior gets
// pinhole voids and a few dry streaks, like a stamp pressed unevenly.
// Usage: swift Assets/make_stamp_mask.swift   (writes docs/assets/stamp-mask.png)
import AppKit

let W = 640, H = 200
var rng = SystemRandomNumberGenerator()
func r() -> Double { Double.random(in: 0..<1, using: &rng) }

// smooth value noise
let G = 24
var grid = (0..<(G * G)).map { _ in r() }
func noise(_ x: Double, _ y: Double) -> Double {
    let gx = x * Double(G - 1), gy = y * Double(G - 1)
    let x0 = Int(gx), y0 = Int(gy), x1 = min(x0 + 1, G - 1), y1 = min(y0 + 1, G - 1)
    let fx = gx - Double(x0), fy = gy - Double(y0)
    let sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy)
    let a = grid[y0 * G + x0], b = grid[y0 * G + x1], c = grid[y1 * G + x0], d = grid[y1 * G + x1]
    return (a + (b - a) * sx) + ((c + (d - c) * sx) - (a + (b - a) * sx)) * sy
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let data = rep.bitmapData!
let streaks = (0..<3).map { _ in (y: r(), w: 0.01 + r() * 0.015, s: 0.12 + r() * 0.12) }
for y in 0..<H {
    for x in 0..<W {
        let u = Double(x) / Double(W - 1), v = Double(y) / Double(H - 1)
        let edge = min(min(u, 1 - u) * Double(W) / Double(H), min(v, 1 - v)) // 0 at border
        let rim = max(0, 1 - edge / 0.12)                                   // 1 near the rim
        var ink = 0.9 + 0.2 * rim + (noise(u, v) - 0.5) * 0.28               // uneven pressure
        for st in streaks where abs(v - st.y) < st.w { ink -= st.s * (1 - rim) * (0.6 + 0.4 * noise(u * 2, v)) }
        if r() < 0.05 * (1 - rim) { ink -= 0.6 }                             // pinhole voids
        if r() < 0.01 { ink -= 0.35 }
        let a = UInt8(max(0, min(1, ink)) * 255)
        let px = data + y * rep.bytesPerRow + x * 4
        px[0] = a; px[1] = a; px[2] = a; px[3] = a   // premultiplied white
    }
}
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "docs/assets/stamp-mask.png"))
print("docs/assets/stamp-mask.png written")
