import AppKit
import CoreImage
import Vision

enum Imaging {
    static func bitmap(_ image: NSImage) -> NSBitmapImageRep? {
        guard let data = image.tiffRepresentation else { return nil }
        return NSBitmapImageRep(data: data)
    }

    static func png(_ image: NSImage) -> Data? {
        bitmap(image)?.representation(using: .png, properties: [:])
    }

    static func normalized(_ image: NSImage) -> NSImage {
        guard let rep = bitmap(image) else { return image }
        let result = NSImage(size: NSSize(width: rep.pixelsWide, height: rep.pixelsHigh))
        result.addRepresentation(rep)
        return result
    }

    static func render(size: NSSize, draw: () -> Void) -> NSImage {
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        var rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep = rep.retagging(with: .sRGB)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        draw()
        NSGraphicsContext.restoreGraphicsState()
        let result = NSImage(size: NSSize(width: width, height: height))
        result.addRepresentation(rep)
        return result
    }

    static func transformed(_ image: NSImage, quarterTurns: Int = 0, flipX: Bool = false, flipY: Bool = false) -> NSImage {
        let odd = abs(quarterTurns) % 2 == 1
        let size = odd ? NSSize(width: image.size.height, height: image.size.width) : image.size
        return render(size: size) {
            let transform = NSAffineTransform()
            transform.translateX(by: size.width / 2, yBy: size.height / 2)
            transform.rotate(byDegrees: CGFloat(quarterTurns) * 90)
            transform.scaleX(by: flipX ? -1 : 1, yBy: flipY ? -1 : 1)
            transform.translateX(by: -image.size.width / 2, yBy: -image.size.height / 2)
            transform.concat()
            image.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
        }
    }

    static func crop(_ image: NSImage, rect: NSRect) -> NSImage {
        let clipped = rect.integral.intersection(NSRect(origin: .zero, size: image.size))
        guard clipped.width >= 1, clipped.height >= 1 else { return image }
        return render(size: clipped.size) {
            image.draw(in: NSRect(origin: .zero, size: clipped.size), from: clipped,
                       operation: .copy, fraction: 1, respectFlipped: false, hints: nil)
        }
    }

    static func filtered(_ image: NSImage, rect: NSRect, mosaic: Bool, strength: CGFloat = 14) -> NSImage {
        guard let data = png(image), let input = CIImage(data: data) else { return image }
        let amount = Double(min(80, max(2, strength)))
        let filter = input.clampedToExtent().applyingFilter(mosaic ? "CIPixellate" : "CIGaussianBlur",
            parameters: mosaic ? [kCIInputScaleKey: amount] : [kCIInputRadiusKey: amount])
        let context = CIContext(options: [.useSoftwareRenderer: true])
        guard let cg = context.createCGImage(filter, from: input.extent) else { return image }
        let filtered = NSImage(cgImage: cg, size: image.size)
        let area = rect.integral.intersection(NSRect(origin: .zero, size: image.size))
        return render(size: image.size) {
            image.draw(at: .zero, from: .zero, operation: .copy, fraction: 1)
            filtered.draw(in: area, from: area, operation: .copy, fraction: 1)
        }
    }

    static func textImage(_ text: String) -> NSImage {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24), .foregroundColor: NSColor.labelColor]
        let textRect = (text as NSString).boundingRect(with: NSSize(width: 800, height: 4000),
            options: [.usesLineFragmentOrigin], attributes: attributes)
        let size = NSSize(width: max(160, ceil(textRect.width) + 48), height: max(80, ceil(textRect.height) + 48))
        return render(size: size) {
            NSColor.textBackgroundColor.setFill()
            NSRect(origin: .zero, size: size).fill()
            (text as NSString).draw(in: NSRect(x: 24, y: 24, width: size.width - 48, height: size.height - 48), withAttributes: attributes)
        }
    }

    static func colorImage(_ color: NSColor) -> NSImage {
        render(size: NSSize(width: 320, height: 180)) {
            color.setFill()
            NSRect(x: 0, y: 0, width: 320, height: 180).fill()
            let rgb = color.usingColorSpace(.sRGB) ?? color
            let foreground: NSColor = (rgb.redComponent * 0.299 + rgb.greenComponent * 0.587 + rgb.blueComponent * 0.114) > 0.55 ? .black : .white
            (hex(rgb) as NSString).draw(at: NSPoint(x: 24, y: 24), withAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 26, weight: .medium), .foregroundColor: foreground])
        }
    }

    static func hex(_ color: NSColor) -> String {
        let rgb = color.usingColorSpace(.sRGB) ?? .black
        return String(format: "#%02X%02X%02X", Int((rgb.redComponent * 255).rounded()),
                      Int((rgb.greenComponent * 255).rounded()), Int((rgb.blueComponent * 255).rounded()))
    }

    static func parseColor(_ string: String) -> NSColor? {
        let text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.hasPrefix("#"), text.count == 7, let value = UInt32(text.dropFirst(), radix: 16) else { return nil }
        return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                       green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255, alpha: 1)
    }

    static func recognize(_ image: NSImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let data = png(image) else { completion(.failure(CocoaError(.fileReadCorruptFile))); return }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                let languages = try request.supportedRecognitionLanguages()
                request.recognitionLanguages = ["ko-KR", "en-US"].filter { languages.contains($0) }
                request.automaticallyDetectsLanguage = true
                request.usesLanguageCorrection = true
                try VNImageRequestHandler(data: data).perform([request])
                let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                DispatchQueue.main.async { completion(.success(text)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
}

@discardableResult func copyImage(_ image: NSImage, to pasteboard: NSPasteboard = .general) -> Bool {
    guard let png = Imaging.png(image) else { return false }
    pasteboard.clearContents()
    var types: [NSPasteboard.PasteboardType] = [.png]
    if image.tiffRepresentation != nil { types.append(.tiff) }
    pasteboard.declareTypes(types, owner: nil)
    let success = pasteboard.setData(png, forType: .png)
    if let tiff = image.tiffRepresentation { pasteboard.setData(tiff, forType: .tiff) }
    return success
}

func saveImage(_ image: NSImage, parent: NSWindow? = nil) {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.png, .jpeg, .tiff]
    panel.nameFieldStringValue = "Promecapt-\(Int(Date().timeIntervalSince1970)).png"
    let save: (NSApplication.ModalResponse) -> Void = { response in
        guard response == .OK, let url = panel.url, let rep = Imaging.bitmap(image) else { return }
        let format: NSBitmapImageRep.FileType = ["jpg", "jpeg"].contains(url.pathExtension.lowercased()) ? .jpeg : (url.pathExtension.lowercased() == "tiff" ? .tiff : .png)
        do {
            guard let data = rep.representation(using: format, properties: [.compressionFactor: 0.95]) else { return }
            try data.write(to: url, options: .atomic)
        } catch { showError(error.localizedDescription) }
    }
    if let parent { panel.beginSheetModal(for: parent, completionHandler: save) }
    else { save(panel.runModal()) }
}

func showError(_ message: String) {
    NSApp.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    alert.messageText = "Promecapt"
    alert.informativeText = message
    alert.runModal()
}
