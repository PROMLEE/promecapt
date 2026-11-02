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
        var failures: [String] = []
        func layoutCheck(_ condition: @autoclosure () -> Bool, _ description: String) {
            if condition() { Checks.count += 1 }
            else {
                failures.append(description)
                FileHandle.standardError.write(Data(("LAYOUT FAIL: " + description + "\n").utf8))
            }
        }
        func inspect(_ view: NSView, context: String) {
            if let stack = view as? NSStackView {
                let children = stack.arrangedSubviews.filter { !$0.isHiddenOrHasHiddenAncestor && $0.frame.width > 0 && $0.frame.height > 0 }
                for (index, child) in children.enumerated() {
                    let rect = child.alignmentRect(forFrame: child.frame)
                    layoutCheck(stack.bounds.insetBy(dx: -0.5, dy: -0.5).contains(rect), "\(context): \(type(of: child)) fits its row \(rect) in \(stack.bounds)")
                    for other in children.dropFirst(index + 1) {
                        let overlap = rect.intersection(other.alignmentRect(forFrame: other.frame))
                        layoutCheck(overlap.isNull || overlap.width < 0.5 || overlap.height < 0.5, "\(context): adjacent controls do not overlap")
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
                layoutCheck(root.bounds.insetBy(dx: -0.5, dy: -0.5).contains(rect), "\(context): native control drawing stays inside the toolbar")
                for other in controls.dropFirst(index + 1) {
                    // A segmented control's internal implementation may contain child controls.
                    if control.isDescendant(of: other) || other.isDescendant(of: control) { continue }
                    let overlap = rect.intersection(other.convert(other.bounds, to: root))
                    layoutCheck(overlap.isNull || overlap.width < 0.5 || overlap.height < 0.5, "\(context): \(type(of: control)) \(rect) overlaps \(type(of: other)) \(other.convert(other.bounds, to: root))")
                }
            }
        }
        func optionVisible(_ root: NSView, id: String) -> Bool {
            func find(_ view: NSView) -> NSView? {
                if view.identifier?.rawValue == id { return view }
                let children = (view as? NSStackView)?.arrangedSubviews ?? view.subviews
                return children.compactMap { find($0) }.first
            }
            guard let view = find(root) else { fatalError("Missing option: " + id) }
            return !view.isHiddenOrHasHiddenAncestor
        }
        func inspectOptions(_ root: NSView, tool: DrawingTool, blackbox: Bool = false, active: Bool = true) {
            layoutCheck(optionVisible(root, id: "redaction-style") == (active && tool == .conceal), "\(tool): redaction menu is contextual")
            layoutCheck(optionVisible(root, id: "annotation-color") == (active && ![DrawingTool.select, .crop, .conceal].contains(tool)), "\(tool): color picker is contextual")
            layoutCheck(optionVisible(root, id: "annotation-parameter") == (active && ![DrawingTool.select, .crop].contains(tool) && !blackbox), "\(tool): numeric parameter is contextual")
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
                bar.onSizeChange = { [weak window, weak bar] in
                    if let bar { window?.setContentSize(bar.preferredSize) }
                }
                bar.info.stringValue = L("기록 {0}/{1} · , 이전 / . 다음", 100, 100)
                window.setContentSize(bar.preferredSize)
                window.contentView?.layoutSubtreeIfNeeded()
                inspect(bar, context: context)
                let rows = bar.subviews.compactMap { $0 as? NSStackView }
                layoutCheck(rows.count == 2 && !rows[0].frame.intersects(rows[1].frame), "\(context): toolbar rows do not overlap")
                inspectControls(bar, context: context)
                layoutCheck(bar.frame.width < 440, "\(context): hidden options no longer leave a 560pt toolbar")
                if appearance == .darkAqua,
                   let pencil = rows.first?.arrangedSubviews.compactMap({ $0 as? AnnotationButton }).first(where: { $0.tag == 1 }),
                   let bitmap = pencil.bitmapImageRepForCachingDisplay(in: pencil.bounds) {
                    pencil.cacheDisplay(in: pencil.bounds, to: bitmap)
                    var whitePixels = 0
                    for y in (bitmap.pixelsHigh / 4)..<(bitmap.pixelsHigh * 3 / 4) {
                        for x in (bitmap.pixelsWide / 4)..<(bitmap.pixelsWide * 3 / 4) {
                            if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                               color.redComponent > 0.95 && color.greenComponent > 0.95 && color.blueComponent > 0.95 {
                                whitePixels += 1
                            }
                        }
                    }
                    layoutCheck(whitePixels > 0, "\(context): inactive-window enabled icon actually renders white")
                }
                let confirm = AnnotationColorWell().confirmationAccessory()
                confirm.appearance = NSAppearance(named: appearance)
                confirm.layoutSubtreeIfNeeded()
                let apply = confirm.subviews.compactMap { $0 as? NSButton }.first!
                layoutCheck(apply.title == L("확인") && apply.keyEquivalent == "\r", "\(context): color picker has an explicit Apply action")
                layoutCheck(confirm.bounds.contains(apply.frame), "\(context): color confirmation button fits its footer")
                try snapshot(confirm, name: "color-footer-" + context)
                try snapshot(bar, name: "capture-" + context)
                // Hidden GIF and changing tool state must not disturb neighboring controls.
                bar.onRecord = nil
                bar.choose(9)
                bar.layoutSubtreeIfNeeded()
                inspect(bar, context: context + "-redact")
                inspectControls(bar, context: context + "-redact")
                try snapshot(bar, name: "redact-" + context)
                let canvas = CanvasView(image: NSImage(size: NSSize(width: 640, height: 400)))
                for (index, tool) in DrawingTool.allCases.filter({ $0 != .crop }).enumerated() {
                    canvas.tool = tool
                    bar.choose(index)
                    bar.sync(with: canvas)
                    bar.layoutSubtreeIfNeeded()
                    inspectOptions(bar, tool: tool)
                    inspectControls(bar, context: context + "-" + tool.rawValue)
                }
                let selectedShape = AnnotationObject(tool: .rectangle, points: [.zero, NSPoint(x: 20, y: 20)], color: AnnotationColor(.systemRed), lineWidth: 4, strength: 14, concealStyle: .mosaic)
                canvas.addAnnotation(selectedShape)
                canvas.tool = .select
                canvas.selectAnnotation(selectedShape.id)
                bar.choose(0)
                bar.sync(with: canvas)
                bar.layoutSubtreeIfNeeded()
                inspectOptions(bar, tool: .rectangle)
                bar.choose(-1)
                bar.sync(with: canvas)
                bar.layoutSubtreeIfNeeded()
                inspectOptions(bar, tool: .select, active: false)
                bar.choose(9)
                canvas.tool = .conceal
                canvas.concealStyle = .blackbox
                bar.sync(with: canvas)
                bar.layoutSubtreeIfNeeded()
                inspectOptions(bar, tool: .conceal, blackbox: true)
                canvas.beginOCRSelection { _ in }
                bar.sync(with: canvas)
                bar.layoutSubtreeIfNeeded()
                inspectOptions(bar, tool: .select, active: false)
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
                for tool in DrawingTool.allCases {
                    editor.canvas.tool = tool
                    editor.canvas.onChange?()
                    editor.window?.contentView?.layoutSubtreeIfNeeded()
                    if let content = editor.window?.contentView {
                        inspectOptions(content, tool: tool)
                        inspectControls(content, context: context + "-editor-" + tool.rawValue)
                    }
                }
                editor.window?.close()
                window.close()
            }
        }
        Checks.check(failures.isEmpty, "All toolbar layouts are free of overlaps and clipping (\(failures.count) failures)")
    }
}
