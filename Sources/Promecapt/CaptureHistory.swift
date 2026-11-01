import AppKit

struct CaptureHistoryContext {
    let image: NSImage
    let selection: NSRect // pixels in image coordinates, bottom-left origin
}

struct CaptureHistoryItem {
    let image: NSImage
    var context: CaptureHistoryContext? = nil
}

struct CaptureHistoryCursor {
    private(set) var index = -1
    mutating func move(older: Bool, count: Int) -> Int? {
        let next = older ? index + 1 : index - 1
        guard next >= -1, next < count, next != index else { return nil }
        index = next; return next
    }
}

enum CaptureHistoryLayout {
    static func place(_ image: NSImage, in surface: CaptureSurface) -> (AnnotationDocument, NSRect) {
        place(CaptureHistoryItem(image: image), in: surface)
    }
    static func place(_ item: CaptureHistoryItem, in surface: CaptureSurface) -> (AnnotationDocument, NSRect) {
        let source = item.context?.image ?? item.image
        let fit = min(1, min(surface.image.size.width / source.size.width, surface.image.size.height / source.size.height))
        // Grow the backing canvas rather than resampling history pixels on smaller screens.
        let size = NSSize(width: (surface.image.size.width / fit).rounded(.up), height: (surface.image.size.height / fit).rounded(.up))
        let placement = NSRect(x: ((size.width - source.size.width) / 2).rounded(),
                               y: ((size.height - source.size.height) / 2).rounded(), width: source.size.width, height: source.size.height)
        let pixels = item.context.map { $0.selection.offsetBy(dx: placement.minX, dy: placement.minY) } ?? placement
        let base = Imaging.render(size: size) {
            // Legacy cropped-only records use this capture's desktop as context, never a black canvas.
            surface.image.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1)
            source.draw(in: placement, from: .zero, operation: .copy, fraction: 1)
        }
        let bounds = surface.screen.frame.size
        return (AnnotationDocument(base: base), NSRect(x: pixels.minX * bounds.width / size.width,
            y: pixels.minY * bounds.height / size.height, width: pixels.width * bounds.width / size.width,
            height: pixels.height * bounds.height / size.height))
    }
}
