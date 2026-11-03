import AppKit

struct GIFOptions {
    static let frameRates = [5, 10, 15, 20, 25, 30]
    static let dimensions = [640, 1280, 1920, 0]
    static let durations = [15, 30, 60]
    let frameRate: Int
    let maxDimension: Int
    let duration: Int
    let showsCursor: Bool
    init(frameRate: Int = 10, maxDimension: Int = 1280, duration: Int = 30, showsCursor: Bool = false) {
        self.frameRate = Self.frameRates.contains(frameRate) ? frameRate : 10
        self.maxDimension = Self.dimensions.contains(maxDimension) ? maxDimension : 1280
        self.duration = Self.durations.contains(duration) ? duration : 30
        self.showsCursor = showsCursor
    }
    static var current: Self {
        let defaults = UserDefaults.standard
        return Self(frameRate: defaults.object(forKey: "gifFrameRate") as? Int ?? 10,
                    maxDimension: defaults.object(forKey: "gifMaxDimension") as? Int ?? 1280,
                    duration: defaults.object(forKey: "gifDuration") as? Int ?? 30,
                    showsCursor: defaults.bool(forKey: "gifShowsCursor"))
    }
    func pixelSize(for rect: NSRect, scale: CGFloat) -> NSSize {
        let factor = maxDimension == 0 ? scale : min(scale, CGFloat(maxDimension) / max(1, max(rect.width, rect.height)))
        return NSSize(width: max(2, (rect.width * factor).rounded()), height: max(2, (rect.height * factor).rounded()))
    }
}

final class GIFRecordingRegion: NSView {
    let region: NSRect
    init(frame: NSRect, region: NSRect) { self.region = region; super.init(frame: frame) }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        let shade = NSBezierPath(rect: bounds); shade.appendRect(region); shade.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.15).setFill(); shade.fill()
        let border = NSBezierPath(rect: region.insetBy(dx: -1, dy: -1))
        border.lineWidth = 2; border.setLineDash([6, 4], count: 2, phase: 0)
        NSColor.systemRed.setStroke(); border.stroke()
        let text = L("● GIF 녹화 영역")
        (text as NSString).draw(at: NSPoint(x: max(4, region.minX + 6), y: min(bounds.maxY - 22, region.maxY + 5)),
                                withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: NSColor.white,
                                                 .backgroundColor: NSColor.black.withAlphaComponent(0.7)])
    }
}

/// Global AppKit coordinates; never fall back to the main display for recording controls.
enum GIFControlPlacement {
    static func frame(near region: NSRect, visibleFrame: NSRect, size: NSSize) -> NSRect {
        let bounds = visibleFrame.insetBy(dx: 10, dy: 10)
        let width = min(size.width, bounds.width), height = min(size.height, bounds.height)
        let below = region.minY - height - 10
        let preferredY = below >= bounds.minY ? below : region.maxY + 10
        return NSRect(x: min(max(region.minX, bounds.minX), bounds.maxX - width),
                      y: min(max(preferredY, bounds.minY), bounds.maxY - height), width: width, height: height)
    }
}
