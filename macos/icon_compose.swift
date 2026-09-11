// Build a proper macOS app icon: a deep-blue gradient background with the whale
// character composited on top, sized so it survives the system's squircle mask.
//
// Usage: icon_compose <character.png> <out.png> [size]
import AppKit

let args = CommandLine.arguments
let charPath = args.count > 1 ? args[1] : "/tmp/whale-assets/whale256.png"
let outPath = args.count > 2 ? args[2] : "/tmp/icon_composed.png"
let S = args.count > 3 ? (Int(args[3]) ?? 1024) : 1024
let px = CGFloat(S)

guard let char = NSImage(contentsOfFile: charPath) else {
    print("cannot load character: \(charPath)"); exit(1)
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: S, pixelsHigh: S,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                           isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// 1. diagonal deep-blue gradient background covering the whole canvas.
//    bgAlpha lets us test a fully transparent background (bgAlpha=0).
let bgAlpha = args.count > 7 ? CGFloat(Double(args[7]) ?? 1.0) : 1.0
let top = NSColor(srgbRed: 0.36, green: 0.47, blue: 0.78, alpha: bgAlpha)   // #5B78C7
let bottom = NSColor(srgbRed: 0.15, green: 0.20, blue: 0.40, alpha: bgAlpha) // #263366
let grad = NSGradient(starting: top, ending: bottom)!
grad.draw(in: NSRect(x: 0, y: 0, width: px, height: px), angle: -90)
print("  background alpha: \(bgAlpha)")

// 2. (glow omitted — the gradient alone reads better at small sizes)

// 3. the character. The source is a head-and-shoulders crop whose content runs to
//    its bottom edge, so a hard seam is unavoidable if drawn as-is; we dissolve it
//    with a fade in step 4. args: [4]=scale, [5]=vertical offset (fraction of canvas)
let scale = args.count > 4 ? (Double(args[4]) ?? 0.82) : 0.82
let offsetY = args.count > 5 ? (Double(args[5]) ?? 0.12) : 0.12
let fadeFrac = args.count > 6 ? (Double(args[6]) ?? 0.20) : 0.20
let side = px * CGFloat(scale)
let insetX = (px - side) / 2
let originY = px * CGFloat(offsetY)
let box = NSRect(x: insetX, y: originY, width: side, height: side)
print("  character box: x=\(Int(insetX)) y=\(Int(originY)) w=\(Int(side)) h=\(Int(side)) (canvas \(S))")
char.draw(in: box, from: .zero, operation: .sourceOver, fraction: 1.0,
          respectFlipped: false, hints: [.interpolation: NSImageInterpolation.high.rawValue])

// 4. bottom fade: dissolve the crop's hard edge into the background colour.
let bgBottom = NSColor(srgbRed: 0.15, green: 0.20, blue: 0.40, alpha: bgAlpha)
if bgAlpha > 0, fadeFrac > 0, let fade = NSGradient(starting: bgBottom, ending: bgBottom.withAlphaComponent(0)) {
    fade.draw(in: NSRect(x: 0, y: 0, width: px, height: px * CGFloat(fadeFrac)), angle: 90)
}

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    print("encode failed"); exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath) (\(S)x\(S), \(png.count) bytes)")

// Sample a few pixels so we can verify the background really is ours.
func sample(_ x: Int, _ y: Int) -> String {
    guard let c = rep.colorAt(x: x, y: y) else { return "?" }
    return String(format: "#%02X%02X%02X a=%.0f",
                  Int(c.redComponent * 255), Int(c.greenComponent * 255),
                  Int(c.blueComponent * 255), c.alphaComponent * 255)
}
print("  corner(4,4)      :", sample(4, 4))
print("  corner(S-5,4)    :", sample(S - 5, 4))
print("  corner(4,S-5)    :", sample(4, S - 5))
print("  top-centre       :", sample(S / 2, 6))
