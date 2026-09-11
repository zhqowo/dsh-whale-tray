// Export the icon macOS actually resolves for a path, so we can look at it.
import AppKit

let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/Users/zhqowo/Desktop/大肥鱼.app"
let out = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "/tmp/resolved_icon.png"

let icon = NSWorkspace.shared.icon(forFile: path)
print("icon object:", icon)
print("icon size:", icon.size)
print("representations:", icon.representations.map { "\($0.pixelsWide)x\($0.pixelsHigh)" })

icon.size = NSSize(width: 256, height: 256)
guard let tiff = icon.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    print("FAILED to render")
    exit(1)
}
do {
    try png.write(to: URL(fileURLWithPath: out))
    let byteCount = png.count
    let w = rep.pixelsWide
    let h = rep.pixelsHigh
    print("wrote \(out) (\(byteCount) bytes, \(w)x\(h))")
} catch {
    print("write failed:", error)
    exit(1)
}

// Also report what LaunchServices thinks the bundle is
if let bundle = Bundle(path: path) {
    print("bundle id:", bundle.bundleIdentifier ?? "nil")
    print("icon file:", bundle.infoDictionary?["CFBundleIconFile"] ?? "nil")
    print("icon name:", bundle.infoDictionary?["CFBundleIconName"] ?? "nil")
    print("package type:", bundle.infoDictionary?["CFBundlePackageType"] ?? "nil")
    if let name = bundle.infoDictionary?["CFBundleIconFile"] as? String {
        let p = "\(path)/Contents/Resources/\(name)"
        print("icon path exists:", FileManager.default.fileExists(atPath: p))
    }
}
