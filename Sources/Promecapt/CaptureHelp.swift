import AppKit

/// A separate, movable reference card. It is never part of exported image pixels.
final class CaptureHelpView: NSView {
    var onMove: ((NSPoint) -> Void)?
    var onResize: (() -> Void)?
    private var dragPoint: NSPoint?
    private let header = NSButton()
    private let rows = NSStackView()
    private(set) var expanded = UserDefaults.standard.object(forKey: DefaultsKey.captureHelpExpanded) as? Bool ?? true
    var preferredSize: NSSize { NSSize(width: 330, height: expanded ? 328 : 32) }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 8
        header.title = L("단축키 안내 (H)")
        header.bezelStyle = .inline
        header.isBordered = false
        header.target = self; header.action = #selector(toggle)
        header.setAccessibilityLabel(header.title)
        addSubview(header)
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 5
        for (keys, title) in [
            ("Drag / Click", L("영역 지정 / 자동 영역 선택")),
            ("Shift + Drag", L("정사각형")),
            ("⌘ + Drag", L("조절 시작 비율 유지")),
            ("↑ ↓ ← →", L("영역 모드 이동 · Shift 크기 · ⌥ 10pt")),
            ("Tab / ⇧Tab", L("상위 / 하위 자동 영역")),
            ("Space", L("선택 전 창 감지 전환")),
            (", / .", L("이전 / 다음 캡처 기록")),
            ("⌘C / ⌘S", L("복사 / 저장")),
            ("⌘↩ / P", L("화면에 고정")),
            ("O / ⇧O", L("전체 OCR / 부분 OCR")),
            ("⌘Z / ⌘⇧Z", L("실행 취소 / 다시 실행")),
            ("Delete", L("선택한 주석 삭제")),
            ("Wheel", L("두께·가리기 세기 조절")),
            ("⌥ + Drag", L("선택 주석 대신 새로 그리기")),
            ("Esc", L("선택 해제 / OCR·캡처 취소"))
        ] {
            let key = NSTextField(labelWithString: keys)
            key.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
            key.widthAnchor.constraint(equalToConstant: 112).isActive = true
            let label = NSTextField(labelWithString: title)
            label.font = .systemFont(ofSize: 11)
            label.lineBreakMode = .byTruncatingTail
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            let row = NSStackView(views: [key, label]); row.spacing = 6
            rows.addArrangedSubview(row)
        }
        addSubview(rows)
        rows.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rows.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            rows.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            rows.topAnchor.constraint(equalTo: topAnchor, constant: 36)])
        rows.isHidden = !expanded
        setAccessibilityElement(true); setAccessibilityRole(.group)
        setAccessibilityLabel(L("단축키 안내 (H)"))
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layout() {
        super.layout()
        header.frame = NSRect(x: 8, y: bounds.height - 28, width: bounds.width - 16, height: 24)
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.withAlphaComponent(0.62).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()
        NSColor.separatorColor.setStroke()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8).stroke()
    }
    @objc func toggle() {
        expanded.toggle(); rows.isHidden = !expanded
        UserDefaults.standard.set(expanded, forKey: DefaultsKey.captureHelpExpanded)
        onResize?()
    }
    override func mouseDown(with event: NSEvent) { dragPoint = window?.convertPoint(toScreen: event.locationInWindow) }
    override func mouseDragged(with event: NSEvent) {
        guard let previous = dragPoint, let window else { return }
        let point = window.convertPoint(toScreen: event.locationInWindow); dragPoint = point
        onMove?(NSPoint(x: point.x - previous.x, y: point.y - previous.y))
    }
    override func mouseUp(with event: NSEvent) { dragPoint = nil }
    var isBeingDragged: Bool { dragPoint != nil }
    override func scrollWheel(with event: NSEvent) {}
}

/// Moves the shortcut panel out of the pointer's way while the user is choosing or dragging a region.
enum CaptureHelpPlacement {
    static let inset: CGFloat = 12
    /// The screen's visible area (without menu bar and Dock) in the capture view's local coordinates.
    /// Works for displays at negative or vertically arranged global coordinates.
    static func localSafeRect(visibleFrame: NSRect, screenFrame: NSRect, bounds: NSRect) -> NSRect {
        visibleFrame.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY).intersection(bounds)
    }
    /// The origin after the panel is collapsed or expanded. A panel in the upper half of `safe` keeps its top edge,
    /// so the header stays under the pointer; one in the lower half keeps its bottom edge.
    static func resizedOrigin(frame: NSRect, to size: NSSize, safe: NSRect) -> NSPoint {
        NSPoint(x: frame.minX, y: frame.midY > safe.midY ? frame.maxY - size.height : frame.minY)
    }
    /// Returns a new origin when the pointer comes within `margin` of `frame`, otherwise nil.
    /// The panel goes to the corner of `safe` farthest from the pointer, preferring corners clear of `avoid`.
    static func dodgeOrigin(frame: NSRect, pointer: NSPoint, safe: NSRect, avoid: NSRect? = nil, margin: CGFloat = 12) -> NSPoint? {
        guard frame.insetBy(dx: -margin, dy: -margin).contains(pointer) else { return nil }
        let area = safe.insetBy(dx: inset, dy: inset)
        let size = frame.size
        let corners = [NSPoint(x: area.minX, y: area.minY), NSPoint(x: area.maxX - size.width, y: area.minY),
                       NSPoint(x: area.minX, y: area.maxY - size.height), NSPoint(x: area.maxX - size.width, y: area.maxY - size.height)]
        func score(_ origin: NSPoint) -> (Bool, CGFloat) {
            let rect = NSRect(origin: origin, size: size)
            let clear = !(avoid.map { rect.intersects($0) } ?? false)
            return (clear, hypot(rect.midX - pointer.x, rect.midY - pointer.y))
        }
        let candidates = corners.filter { !NSRect(origin: $0, size: size).insetBy(dx: -margin, dy: -margin).contains(pointer) }
        guard let best = candidates.max(by: { a, b in
            let (ca, da) = score(a), (cb, db) = score(b)
            return ca != cb ? !ca : da < db
        }), best != frame.origin else { return nil }
        return best
    }
}
