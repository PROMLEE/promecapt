import AppKit
import ApplicationServices

struct CaptureWindowTarget {
    var rect: NSRect // Screen-local AppKit points, front to back.
    var processID: pid_t
}

struct CaptureTarget: Equatable {
    var rect: NSRect
    var label: String
}

enum CaptureTargetDetail: Int, CaseIterable {
    case fine, balanced, large, windows
    static var current: Self {
        guard let value = UserDefaults.standard.object(forKey: "captureTargetDetail") as? Int else { return .balanced }
        return Self(rawValue: value) ?? .balanced
    }
    var title: String {
        switch self {
        case .fine: return L("세밀하게")
        case .balanced: return L("균형")
        case .large: return L("큰 영역 위주")
        case .windows: return L("창만")
        }
    }
    func filter(_ targets: [CaptureTarget]) -> [CaptureTarget] {
        guard let window = targets.last else { return [] }
        if self == .windows { return [window] }
        let side: CGFloat = self == .fine ? 5 : self == .balanced ? 24 : 64
        let area: CGFloat = self == .fine ? 25 : self == .balanced ? 2400 : 16000
        return targets.dropLast().filter { $0.rect.width >= side && $0.rect.height >= side && $0.rect.width * $0.rect.height >= area } + [window]
    }
}

enum CaptureTargetGeometry {
    static func appKitRect(_ rect: NSRect, mainTop: CGFloat) -> NSRect {
        NSRect(x: rect.minX, y: mainTop - rect.maxY, width: rect.width, height: rect.height)
    }
    static func ordered(elements: [CaptureTarget], window: NSRect, point: NSPoint, bounds: NSRect) -> [CaptureTarget] {
        let limit = window.intersection(bounds)
        guard limit.contains(point) else { return [] }
        func same(_ a: NSRect, _ b: NSRect) -> Bool {
            abs(a.minX - b.minX) < 2 && abs(a.minY - b.minY) < 2 && abs(a.width - b.width) < 2 && abs(a.height - b.height) < 2
        }
        var result: [CaptureTarget] = []
        for element in elements {
            let rect = element.rect.intersection(limit)
            guard rect.width >= 5, rect.height >= 5, rect.contains(point), !same(rect, limit),
                  !result.contains(where: { same($0.rect, rect) }) else { continue }
            result.append(CaptureTarget(rect: rect, label: element.label))
        }
        result.sort { $0.rect.width * $0.rect.height < $1.rect.width * $1.rect.height }
        result.append(CaptureTarget(rect: limit, label: L("창")))
        return result
    }
}

// The capture background is frozen, so geometry can be reused for this session.
struct CaptureTargetCache {
    private var entries: [String: [CaptureTarget]] = [:]
    private func key(_ window: CaptureWindowTarget) -> String { "\(window.processID):\(NSStringFromRect(window.rect))" }
    mutating func remember(_ targets: [CaptureTarget], for window: CaptureWindowTarget) {
        let key = key(window)
        var values = entries[key] ?? []
        for target in targets where target.rect != window.rect {
            if let index = values.firstIndex(where: { $0.rect == target.rect }) { values[index] = target }
            else { values.append(target) }
        }
        entries[key] = Array(values.suffix(512))
    }
    func targets(at point: NSPoint, window: CaptureWindowTarget, bounds: NSRect) -> [CaptureTarget] {
        CaptureTargetGeometry.ordered(elements: entries[key(window)] ?? [], window: window.rect, point: point, bounds: bounds)
    }
}

private final class CaptureDetectionTicket {
    private let lock = NSLock()
    private var stopped = false
    var cancelled: Bool { lock.lock(); defer { lock.unlock() }; return stopped }
    func cancel() { lock.lock(); stopped = true; lock.unlock() }
}

/// Reads only element roles and geometry. No UI actions, text/value reads or event posting.
final class CaptureTargetDetector {
    static var canReadElements: Bool { AXIsProcessTrusted() }
    private let queue = DispatchQueue(label: "com.promlee.promepaste.capture-targets", qos: .userInteractive)
    private var busy = false
    private var generation = 0
    private var pending: (() -> Void)?
    private var ticket: CaptureDetectionTicket?
    private var cache = CaptureTargetCache()

    func cached(at point: NSPoint, window: CaptureWindowTarget, bounds: NSRect) -> [CaptureTarget] {
        cache.targets(at: point, window: window, bounds: bounds)
    }

    static func windows(on screen: NSScreen) -> [CaptureWindowTarget] {
        guard let records = CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        let mainTop = NSScreen.screens.first?.frame.maxY ?? 0
        return records.compactMap { record in
            guard let pid = record[kCGWindowOwnerPID as String] as? NSNumber,
                  pid.int32Value != ProcessInfo.processInfo.processIdentifier,
                  let layer = record[kCGWindowLayer as String] as? NSNumber, [0, 3].contains(layer.intValue),
                  ((record[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1) > 0,
                  let dictionary = record[kCGWindowBounds as String] as? [String: Any],
                  let quartz = CGRect(dictionaryRepresentation: dictionary as CFDictionary) else { return nil }
            let frame = CaptureTargetGeometry.appKitRect(quartz, mainTop: mainTop)
            let local = frame.intersection(screen.frame).offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)
            guard local.width > 20, local.height > 20 else { return nil }
            return CaptureWindowTarget(rect: local, processID: pid.int32Value)
        }
    }
    func cancel() { generation += 1; pending = nil; ticket?.cancel() }
    func detect(at point: NSPoint, screen: NSScreen, window: CaptureWindowTarget, completion: @escaping ([CaptureTarget]) -> Void) {
        cancel()
        let request = CaptureDetectionTicket()
        ticket = request
        let current = generation
        let work = { [weak self] in
            guard let self, !request.cancelled else { return }
            self.busy = true
            let frame = screen.frame, mainTop = NSScreen.screens.first?.frame.maxY ?? 0
            self.queue.async {
                let elements = Self.elements(at: point, screenFrame: frame, mainTop: mainTop, processID: window.processID, ticket: request) { leaf in
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        self.cache.remember([leaf], for: window)
                        guard self.generation == current else { return }
                        completion(CaptureTargetGeometry.ordered(elements: [leaf], window: window.rect, point: point, bounds: NSRect(origin: .zero, size: frame.size)))
                    }
                }
                let result = CaptureTargetGeometry.ordered(elements: elements, window: window.rect, point: point, bounds: NSRect(origin: .zero, size: frame.size))
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.busy = false
                    self.cache.remember(elements, for: window)
                    if self.generation == current { completion(result) }
                    let next = self.pending; self.pending = nil; next?()
                }
            }
        }
        if busy { pending = work } else { work() }
    }
    private static func elements(at point: NSPoint, screenFrame: NSRect, mainTop: CGFloat, processID: pid_t, ticket: CaptureDetectionTicket, onLeaf: @escaping (CaptureTarget) -> Void) -> [CaptureTarget] {
        guard !ticket.cancelled, canReadElements else { return [] }
        let application = AXUIElementCreateApplication(processID)
        AXUIElementSetMessagingTimeout(application, 0.035)
        let global = NSPoint(x: point.x + screenFrame.minX, y: mainTop - point.y - screenFrame.minY)
        var found: AXUIElement?
        _ = AXUIElementCopyElementAtPosition(application, Float(global.x), Float(global.y), &found)
        let deadline = Date().addingTimeInterval(0.10)
        var current: AXUIElement? = found, result: [CaptureTarget] = []
        for _ in 0..<12 {
            guard !ticket.cancelled, let element = current, Date() < deadline else { break }
            AXUIElementSetMessagingTimeout(element, 0.015)
            if let data = elementData(element, mainTop: mainTop, screenFrame: screenFrame) {
                if data.role != kAXApplicationRole as String && data.role != kAXWindowRole as String {
                    let target = CaptureTarget(rect: data.rect, label: label(for: data.role))
                    result.append(target)
                    if result.count == 1 { onLeaf(target) }
                }
            }
            guard let parent = attribute(element, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
            let parentElement = unsafeBitCast(parent, to: AXUIElement.self)
            if CFEqual(element, parentElement) { break }
            current = parentElement
        }
        // Some applications do not implement point hit testing. Walk their exposed
        // windows/children, pruning branches outside the pointer, with a strict budget.
        if (result.isEmpty || [L("웹페이지"), L("구역"), L("스크롤 영역")].contains(result.first?.label ?? "")) && !ticket.cancelled {
            let end = Date().addingTimeInterval(0.16)
            var nodes = found.map { [$0] } ?? (attribute(application, kAXWindowsAttribute) as? [AXUIElement] ?? [])
            var visited = 0
            while !ticket.cancelled && !nodes.isEmpty && visited < 100 && Date() < end {
                let element = nodes.removeFirst(); visited += 1
                AXUIElementSetMessagingTimeout(element, 0.012)
                let data = elementData(element, mainTop: mainTop, screenFrame: screenFrame)
                let rect = data?.rect
                if let rect, rect.width > 0, rect.height > 0, !rect.contains(point) { continue }
                let role = data?.role ?? ""
                if let rect, role != kAXWindowRole as String, role != kAXApplicationRole as String {
                    result.append(CaptureTarget(rect: rect, label: label(for: role)))
                }
                if let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] {
                    nodes.insert(contentsOf: children, at: 0)
                }
            }
        }
        return result
    }
    private static func elementData(_ element: AXUIElement, mainTop: CGFloat, screenFrame: NSRect) -> (rect: NSRect, role: String)? {
        var values: CFArray?
        let status = AXUIElementCopyMultipleAttributeValues(element, [kAXPositionAttribute, kAXSizeAttribute, kAXRoleAttribute] as CFArray, [], &values)
        let batch = status == .success ? values as? [AnyObject] : nil
        let positionValue: CFTypeRef? = batch?.first ?? attribute(element, kAXPositionAttribute)
        let sizeValue: CFTypeRef? = (batch?.count ?? 0) > 1 ? batch?[1] : attribute(element, kAXSizeAttribute)
        let role = ((batch?.count ?? 0) > 2 ? batch?[2] as? String : attribute(element, kAXRoleAttribute) as? String) ?? ""
        guard let positionValue, let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(), CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        var position = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(unsafeBitCast(positionValue, to: AXValue.self), .cgPoint, &position),
              AXValueGetValue(unsafeBitCast(sizeValue, to: AXValue.self), .cgSize, &size) else { return nil }
        return (CaptureTargetGeometry.appKitRect(NSRect(origin: position, size: size), mainTop: mainTop)
            .offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY), role)
    }
    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }
    private static func label(for role: String) -> String {
        ["AXButton":L("버튼"), "AXLink":L("링크"), "AXTextField":L("입력칸"), "AXTextArea":L("텍스트 영역"), "AXStaticText":L("텍스트"),
         "AXImage":L("이미지"), "AXCheckBox":L("체크박스"), "AXRadioButton":L("선택 버튼"), "AXPopUpButton":L("선택 메뉴"),
         "AXComboBox":L("입력 메뉴"), "AXRow":L("목록 행"), "AXTable":L("표"), "AXOutline":L("목록"), "AXToolbar":L("도구 막대"),
         "AXScrollArea":L("스크롤 영역"), "AXWebArea":L("웹페이지"), "AXGroup":L("구역")][role] ?? L("앱 요소")
    }
}
