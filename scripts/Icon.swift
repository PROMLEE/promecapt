import AppKit

@main struct IconGenerator {
    static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for logical in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let pixels = logical * scale
                var rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                rep = rep.retagging(with: .sRGB)!
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                let transform = NSAffineTransform(); transform.scale(by: CGFloat(pixels) / 1024); transform.concat()
                let base = NSBezierPath(roundedRect: NSRect(x: 44, y: 44, width: 936, height: 936), xRadius: 210, yRadius: 210)
                NSGradient(starting: NSColor(srgbRed: 0.12, green: 0.24, blue: 0.48, alpha: 1),
                           ending: NSColor(srgbRed: 0.02, green: 0.14, blue: 0.19, alpha: 1))!.draw(in: base, angle: 60)
                CaptureMark.draw(in: NSRect(x: 258, y: 258, width: 508, height: 508), color: NSColor(srgbRed: 0.66, green: 1, blue: 0.89, alpha: 1))
                NSGraphicsContext.restoreGraphicsState()
                let name = "icon_\(logical)x\(logical)\(scale == 2 ? "@2x" : "").png"
                try rep.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
            }
        }
    }
}
