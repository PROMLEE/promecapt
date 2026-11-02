import AppKit

/// Exercise real AppKit constraints without ordering a window or reading the desktop.
enum ToolbarLayoutChecks {
    static func run() throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let savedLanguage = UserDefaults.standard.object(forKey: "appLanguage")
        defer { UserDefaults.standard.set(savedLanguage, forKey: "appLanguage") }
        let output = URL(fileURLWithPath: ".build/toolbar-layout", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        func inspect(_ view: NSView, context: String) {
            if let stack = view as? NSStackView {
                let children = stack.arrangedSubviews.filter { !$0.isHiddenOrHasHiddenAncestor && $0.frame.width > 0 && $0.frame.height > 0 }
                for (index, child) in children.enumerated() {
                    let rect = child.alignmentRect(forFrame: child.frame)
                    Checks.check(stack.bounds.insetBy(dx: -0.5, dy: -0.5).contains(rect), "\(context): \(type(of: child)) fits its row \(rect) in \(stack.bounds)")
                    for other in children.dropFirst(index + 1) {
                        let overlap = rect.intersection(other.alignmentRect(forFrame: other.frame))
                        Checks.check(overlap.isNull || overlap.width < 0.5 || overlap.height < 0.5, "\(context): adjacent controls do not overlap")
                    }
                }
            }
            for child in view.subviews where !child.isHiddenOrHasHiddenAncestor { inspect(child, context: context) }
        }
        func snapshot(_ view: NSView, name: String) throws {
            view.displayIfNeeded()
            if let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: bitmap)
                if let data = bitmap.representation(using: .png, properties: [:]) {
                    try data.write(to: output.appendingPathComponent(name + ".png"))
                }
            }
        }
        func inspectControls(_ root: NSView, context: String) {
            var controls: [NSControl] = []
            func visit(_ view: NSView) {
                guard !view.isHiddenOrHasHiddenAncestor else { return }
                if let control = view as? NSControl, !(control is NumericStepper) { controls.append(control) }
                for child in view.subviews { visit(child) }
            }
            visit(root)
            for (index, control) in controls.enumerated() {
                let rect = control.convert(control.bounds, to: root)
                Checks.check(root.bounds.insetBy(dx: -0.5, dy: -0.5).contains(rect), "\(context): native control drawing stays inside the toolbar")
                for other in controls.dropFirst(index + 1) {
                    // A segmented control's internal implementation may contain child controls.
                    if control.isDescendant(of: other) || other.isDescendant(of: control) { continue }
                    let overlap = rect.intersection(other.convert(other.bounds, to: root))
                    Checks.check(overlap.isNull || overlap.width < 0.5 || overlap.height < 0.5, "\(context): \(type(of: control)) \(rect) overlaps \(type(of: other)) \(other.convert(other.bounds, to: root))")
                }
            }
        }
        for language in ["ko", "en", "ja", "zh-Hans"] {
            UserDefaults.standard.set(language, forKey: "appLanguage")
            for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                let context = "\(language)-\(appearance.rawValue)"
                let bar = AnnotationBar(frame: NSRect(origin: .zero, size: AnnotationBar.preferredSize))
                bar.appearance = NSAppearance(named: appearance)
                bar.onRecord = {}
                let window = NSWindow(contentRect: bar.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.contentView = bar
                bar.info.stringValue = L("기록 {0}/{1} · , 이전 / . 다음", 100, 100)
                window.contentView?.layoutSubtreeIfNeeded()
                inspect(bar, context: context)
                let rows = bar.subviews.compactMap { $0 as? NSStackView }
                Checks.check(rows.count == 2 && !rows[0].frame.intersects(rows[1].frame), "\(context): toolbar rows do not overlap")
                inspectControls(bar, context: context)
                try snapshot(bar, name: "capture-" + context)
                // Hidden GIF and changing tool state must not disturb neighboring controls.
                bar.onRecord = nil
                bar.choose(9)
                bar.layoutSubtreeIfNeeded()
                inspect(bar, context: context + "-redact")
                inspectControls(bar, context: context + "-redact")
                try snapshot(bar, name: "redact-" + context)
                let canvas = CanvasView(image: NSImage(size: NSSize(width: 640, height: 400)))
                canvas.beginOCRSelection { _ in }
                bar.sync(with: canvas)
                bar.layoutSubtreeIfNeeded()
                inspectControls(bar, context: context + "-ocr")
                try snapshot(bar, name: "ocr-" + context)
                let editor = EditorController(image: NSImage(size: NSSize(width: 640, height: 400)))
                editor.window?.appearance = NSAppearance(named: appearance)
                editor.window?.setContentSize(NSSize(width: 900, height: 500))
                editor.window?.contentView?.layoutSubtreeIfNeeded()
                if let content = editor.window?.contentView {
                    inspect(content, context: context + "-editor-900")
                    inspectControls(content, context: context + "-editor-900")
                    try snapshot(content, name: "editor-900-" + context)
                }
                editor.window?.close()
                window.close()
            }
        }
    }
}
