import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("build/Headroom.iconset")
let output = root.appendingPathComponent("build/Headroom.icns")

try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)

struct IconFile {
    let name: String
    let pixels: Int
}

let files = [
    IconFile(name: "icon_16x16.png", pixels: 16),
    IconFile(name: "icon_16x16@2x.png", pixels: 32),
    IconFile(name: "icon_32x32.png", pixels: 32),
    IconFile(name: "icon_32x32@2x.png", pixels: 64),
    IconFile(name: "icon_128x128.png", pixels: 128),
    IconFile(name: "icon_128x128@2x.png", pixels: 256),
    IconFile(name: "icon_256x256.png", pixels: 256),
    IconFile(name: "icon_256x256@2x.png", pixels: 512),
    IconFile(name: "icon_512x512.png", pixels: 512),
    IconFile(name: "icon_512x512@2x.png", pixels: 1024)
]

func writeIcon(size pixels: Int, to url: URL) throws {
    let size = CGFloat(pixels)
    let image = NSImage(size: NSSize(width: size, height: size))

    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let inset = size * 0.08
    let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = size * 0.22
    let background = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    NSColor(red: 0.08, green: 0.10, blue: 0.12, alpha: 1.0).setFill()
    background.fill()

    let innerRect = rect.insetBy(dx: size * 0.03, dy: size * 0.03)
    let inner = NSBezierPath(roundedRect: innerRect, xRadius: radius * 0.82, yRadius: radius * 0.82)
    NSColor(red: 0.13, green: 0.16, blue: 0.19, alpha: 1.0).setFill()
    inner.fill()

    let dotSize = size * 0.30
    let dotRect = NSRect(
        x: (size - dotSize) / 2,
        y: (size - dotSize) / 2,
        width: dotSize,
        height: dotSize
    )

    let ring = NSBezierPath(ovalIn: dotRect.insetBy(dx: -size * 0.045, dy: -size * 0.045))
    NSColor(red: 0.18, green: 0.75, blue: 0.44, alpha: 0.28).setStroke()
    ring.lineWidth = max(1, size * 0.025)
    ring.stroke()

    let dot = NSBezierPath(ovalIn: dotRect)
    NSColor(red: 0.18, green: 0.75, blue: 0.44, alpha: 1.0).setFill()
    dot.fill()

    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "HeadroomIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to render icon"])
    }

    try png.write(to: url)
}

for file in files {
    try writeIcon(size: file.pixels, to: iconset.appendingPathComponent(file.name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(domain: "HeadroomIcon", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed"])
}
