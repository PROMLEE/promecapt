import AppKit
import ImageIO

@main struct Checks {
    static var count = 0
    static func check(_ condition: @autoclosure () -> Bool, _ description: String) {
        guard condition() else { fatalError("FAIL: \(description)") }
        count += 1
        print("PASS: \(description)")
    }
    static func channelValues<T: FixedWidthInteger>(_ count: Int, _ read: (UnsafeMutablePointer<T>) -> Void) -> [UInt] {
        var values = [T](repeating: 0, count: count)
        values.withUnsafeMutableBufferPointer { read($0.baseAddress!) }
        return values.map { UInt($0) }
    }
    static func pixel(_ image: NSImage, _ x: Int, _ y: Int) -> String {
        let rep = Imaging.bitmap(image)!
        let channels = channelValues(rep.samplesPerPixel) { rep.getPixel($0, atX: x, y: y) }
        return String(format: "#%02X%02X%02X", channels[0], channels[1], channels[2])
    }
    static func main() throws {
        func luminance(_ color: NSColor) -> Double {
            let c = color.usingColorSpace(.sRGB)!
            func linear(_ value: CGFloat) -> Double {
                let v = Double(value)
                return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(c.redComponent) + 0.7152 * linear(c.greenComponent) + 0.0722 * linear(c.blueComponent)
        }
        func contrast(_ a: NSColor, _ b: NSColor) -> Double {
            let x = luminance(a), y = luminance(b)
            return (max(x, y) + 0.05) / (min(x, y) + 0.05)
        }
        check(contrast(AnnotationPalette.foreground, AnnotationPalette.background) >= 7, "toolbar text has strong contrast against its opaque background")
        check(contrast(AnnotationPalette.foreground, AnnotationPalette.control) >= 7, "toolbar icons and labels retain strong contrast on controls")
        check(contrast(AnnotationPalette.foreground, AnnotationPalette.selected) >= 4.5, "selected tool labels retain readable contrast")
        check(contrast(AnnotationPalette.disabled, AnnotationPalette.control) >= 4.5, "disabled toolbar labels remain readable")
        check(contrast(AnnotationPalette.border, AnnotationPalette.control) >= 3, "toolbar button boundaries are visible")
        let savedLanguage = UserDefaults.standard.object(forKey: "appLanguage")
        UserDefaults.standard.set("en", forKey: "appLanguage")
        check(L("캡처") == "Capture" && L("기록 {0}/{1} · , 이전 / . 다음", 1, 3).contains("1/3"), "English UI and interpolation load from catalog")
        check(L("그룹: {0}", "{1}") == "Group: {1}", "localized interpolation preserves literal user placeholders")
        UserDefaults.standard.set("ja", forKey: "appLanguage")
        check(L("저장") == "保存", "Japanese UI catalog loads")
        UserDefaults.standard.set("zh-Hans", forKey: "appLanguage")
        check(L("단축키") == "快捷键", "Simplified Chinese UI catalog loads")
        check(AppLanguage.resolved("auto", preferred: ["fr-FR"]) == "en" && AppLanguage.resolved("auto", preferred: ["ja-JP"]) == "ja", "system language resolves supported locales and English fallback")
        UserDefaults.standard.set("ko", forKey: "appLanguage")
        check(L("캡처") == "캡처" && DrawingTool.rectangle.rawValue == "사각형", "Korean UI and persisted annotation identifiers remain compatible")
        defer { UserDefaults.standard.set(savedLanguage, forKey: "appLanguage") }
        check(CapturePointerStyle.forMode(selectingRegion: true, selectingOCR: false) == .crosshair, "region selection requests crosshair")
        check(CapturePointerStyle.forMode(selectingRegion: false, selectingOCR: false) == .arrow, "annotation mode requests arrow")
        check(CapturePointerStyle.forMode(selectingRegion: false, selectingOCR: true) == .crosshair, "OCR region selection can request a crosshair explicitly")
        let targetWindow = NSRect(x: 10, y: 20, width: 500, height: 400)
        let button = CaptureTarget(rect: NSRect(x: 40, y: 50, width: 80, height: 30), label: "버튼")
        let group = CaptureTarget(rect: NSRect(x: 30, y: 40, width: 200, height: 100), label: "구역")
        let ordered = CaptureTargetGeometry.ordered(elements: [group, button, button, CaptureTarget(rect: targetWindow, label: "창")], window: targetWindow, point: NSPoint(x: 50, y: 60), bounds: NSRect(x: 0,y: 0,width: 1000,height: 800))
        check(ordered.map(\.label) == ["버튼", "구역", "창"], "auto target orders smallest control then ancestors and window, removes duplicate geometry")
        check(CaptureTargetGeometry.ordered(elements: [button], window: targetWindow, point: .zero, bounds: targetWindow).isEmpty, "auto target excludes windows outside pointer")
        let clipped = CaptureTargetGeometry.ordered(elements: [CaptureTarget(rect: NSRect(x: -20,y: -20,width: 100,height: 100), label: "구역")], window: NSRect(x: -50,y: -50,width: 300,height: 300), point: NSPoint(x: 20,y: 20), bounds: NSRect(x: 0,y: 0,width: 200,height: 200))
        check(clipped.first?.rect == NSRect(x: 0,y: 0,width: 80,height: 80), "auto target clips controls to visible screen and window")
        check(CaptureTargetGeometry.appKitRect(NSRect(x: -1920,y: 100,width: 100,height: 200), mainTop: 1080) == NSRect(x: -1920,y: 780,width: 100,height: 200), "auto target converts Quartz geometry on secondary screen")
        var targetCache = CaptureTargetCache()
        let cacheWindow = CaptureWindowTarget(rect: targetWindow, processID: 123)
        targetCache.remember([button, group], for: cacheWindow)
        check(targetCache.targets(at: NSPoint(x: 55,y: 60), window: cacheWindow, bounds: targetWindow).first == button, "moving within a detected button reuses geometry immediately")
        let sibling = CaptureTarget(rect: NSRect(x: 140,y: 50,width: 60,height: 30),label: "입력칸")
        targetCache.remember([sibling], for: cacheWindow)
        check(targetCache.targets(at: NSPoint(x: 150,y: 60), window: cacheWindow, bounds: targetWindow).first == sibling, "moving back to a sibling uses cached geometry without an AX round trip")
        check(targetCache.targets(at: NSPoint(x: 50,y: 60), window: cacheWindow, bounds: targetWindow).first == button, "new target discovery preserves earlier button geometry")
        check(targetCache.targets(at: NSPoint(x: 300,y: 300), window: cacheWindow, bounds: targetWindow).first?.label == "창", "leaving cached controls falls back to the current window")
        check(targetCache.targets(at: NSPoint(x: 50,y: 60), window: CaptureWindowTarget(rect: targetWindow, processID: 456), bounds: targetWindow).first?.label == "창", "cached geometry never leaks into a different application")
        check(NumericStepper.parsedValue(" 12 ", min: 1, max: 32) == 12, "numeric thickness accepts direct integer entry")
        check(NumericStepper.parsedValue("99", min: 1, max: 32) == 32 && NumericStepper.parsedValue("-2", min: 1, max: 32) == 1, "numeric thickness input stays within supported range")
        check(NumericStepper.parsedValue("text", min: 1, max: 32) == nil && NumericStepper.parsedValue("1.5", min: 1, max: 32) == nil, "numeric control rejects invalid and fractional input")
        check(NumericStepper.parsedValue("80", min: 2, max: 80) == 80, "numeric effect strength uses the independent effect range")
        let image = Imaging.render(size: NSSize(width: 80, height: 40)) {
            NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: 40, height: 40).fill()
            NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1).setFill(); NSRect(x: 40, y: 0, width: 40, height: 40).fill()
        }
        let png = Imaging.png(image)!
        let decoded = NSImage(data: png)!
        check(Imaging.bitmap(decoded)!.pixelsWide == 80 && Imaging.bitmap(decoded)!.pixelsHigh == 40, "PNG pixel dimensions")
        check(pixel(decoded, 10, 10) == "#FF0000" && pixel(decoded, 60, 10) == "#0000FF", "PNG pixel content (\(pixel(decoded, 10, 10)), \(pixel(decoded, 60, 10)))")
        let flip = Imaging.transformed(image, flipX: true)
        check(pixel(flip, 10, 10) == "#0000FF", "horizontal flip")
        let rotated = Imaging.transformed(image, quarterTurns: 1)
        check(rotated.size == NSSize(width: 40, height: 80), "rotation dimensions")
        check(pixel(Imaging.transformed(rotated, quarterTurns: -1), 10, 10) == "#FF0000", "rotation round trip")
        let crop = Imaging.crop(image, rect: NSRect(x: 40, y: 0, width: 40, height: 40))
        check(crop.size == NSSize(width: 40, height: 40) && pixel(crop, 10, 10) == "#0000FF", "crop coordinates")
        check(Imaging.crop(image, rect: .zero) === image, "empty crop is safe")
        check(Imaging.crop(image, rect: NSRect(x: 200, y: 200, width: 10, height: 10)) === image, "out-of-bounds crop is safe")
        check(Imaging.hex(Imaging.parseColor("  #2C77FF\n")!) == "#2C77FF", "HEX parsing")
        check(Imaging.parseColor("#GG0000") == nil && Imaging.parseColor("red") == nil, "reject invalid colors")
        var historyCursor = CaptureHistoryCursor()
        check(historyCursor.move(older: true, count: 0) == nil && historyCursor.index == -1, "empty capture history preserves current capture")
        check(historyCursor.move(older: true, count: 2) == 0 && historyCursor.move(older: true, count: 2) == 1, "comma browses newest history then older history")
        check(historyCursor.move(older: true, count: 2) == nil && historyCursor.index == 1, "oldest history does not wrap or reset")
        check(historyCursor.move(older: false, count: 2) == 0 && historyCursor.move(older: false, count: 2) == -1, "period returns through history to current capture")
        check(historyCursor.move(older: false, count: 2) == nil, "current capture is the forward boundary")
        if let screen = NSScreen.screens.first {
            let surface = CaptureSurface(screen: screen, image: Imaging.render(size: NSSize(width: 160,height: 100)) {})
            let state = CaptureHistoryLayout.place(image, in: surface)
            var area = CaptureSelection(bounds: NSRect(origin: .zero, size: screen.frame.size)); area.rect = state.1
            let restored = state.0.cropped(to: area.pixelRect(imageSize: state.0.base.size)).rendered()
            check(restored.size == image.size && pixel(restored, 10,10) == pixel(image,10,10), "history centered placement exports original pixel size and colors")
        }
        if let screen = NSScreen.screens.first {
            let large = Imaging.render(size: NSSize(width: 320,height: 200)) { NSColor.red.setFill(); NSRect(x: 0,y: 0,width: 320,height: 200).fill() }
            let state = CaptureHistoryLayout.place(large, in: CaptureSurface(screen: screen, image: Imaging.render(size: NSSize(width: 160,height: 100)) {}))
            var area = CaptureSelection(bounds: NSRect(origin: .zero,size: screen.frame.size)); area.rect = state.1
            check(state.0.cropped(to: area.pixelRect(imageSize: state.0.base.size)).base.size == large.size, "history larger than the screen retains original export resolution")
        }
        let overlay = GIFRecordingRegion(frame: NSRect(x: 0,y: 0,width: 160,height: 100), region: NSRect(x: 20,y: 20,width: 80,height: 40))
        let overlaid = Imaging.render(size: NSSize(width: 160,height: 100)) {
            NSColor.green.setFill(); NSRect(x: 0,y: 0,width: 160,height: 100).fill()
            overlay.draw(overlay.bounds)
        }
        check(pixel(overlaid, 50, 60) == "#00FF00", "GIF recording overlay leaves the selected screen area transparent")
        let shaded = pixel(overlaid, 150, 90)
        check(shaded != "#00FF00" && shaded != "#000000" && shaded != "#FFFFFF", "GIF recording overlay dims outside while preserving underlying screen content")
        let native = GIFOptions(frameRate: 30, maxDimension: 0, duration: 60)
        check(native.pixelSize(for: NSRect(x: 0,y: 0,width: 800,height: 400), scale: 2) == NSSize(width: 1600,height: 800), "GIF original resolution preserves Retina pixels")
        check(GIFOptions(maxDimension: 640).pixelSize(for: NSRect(x: 0,y: 0,width: 800,height: 400), scale: 2) == NSSize(width: 640,height: 320), "GIF configured long edge preserves aspect ratio")
        check(GIFOptions(maxDimension: 1920).pixelSize(for: NSRect(x: 0,y: 0,width: 80,height: 40), scale: 1) == NSSize(width: 80,height: 40), "GIF resolution setting never upscales")
        check(GIFOptions(frameRate: 999, maxDimension: -1, duration: -1).frameRate == 10, "invalid GIF settings recover safe defaults")
        if let screen = NSScreen.main {
            let background = Imaging.render(size: NSSize(width: 160,height: 100)) {
                NSColor.green.setFill(); NSRect(x: 0,y: 0,width: 160,height: 100).fill()
                image.draw(in: NSRect(x: 20,y: 30,width: 80,height: 40))
            }
            let surface = CaptureSurface(screen: screen, image: background)
            let legacy = CaptureHistoryLayout.place(image, in: surface)
            check(pixel(legacy.0.base, 2, 2) == "#00FF00", "legacy history shows current desktop outside crop instead of black")
            let context = CaptureHistoryContext(image: background, selection: NSRect(x: 20,y: 30,width: 80,height: 40))
            let restored = CaptureHistoryLayout.place(CaptureHistoryItem(image: image, context: context), in: surface)
            var selection = CaptureSelection(bounds: NSRect(origin: .zero,size: screen.frame.size)); selection.rect = restored.1
            check(selection.pixelRect(imageSize: restored.0.base.size) == context.selection, "history restores original selection position and pixel bounds")
            check(pixel(restored.0.base, 2, 2) == "#00FF00", "history retains original full screen pixels outside selection")
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("PromecaptContextCheck-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: root) }
            let library = try Library(root: root)
            let entry = try library.add(image, context: context)
            let reloaded = try Library(root: root)
            check(reloaded.historyItem(entry)?.context?.selection == context.selection && reloaded.historyItem(entry)?.context?.image.size == background.size, "history context and position survive disk reload")
            try reloaded.clearHistory()
            check(!FileManager.default.fileExists(atPath: reloaded.historyContextURL(entry).path), "clearing history also removes full screen context")
        }
        let gif = try GIFArchive()
        defer { gif.removeTemporaryFiles() }
        try gif.append(Imaging.bitmap(image)!.cgImage!, at: 0)
        try gif.append(Imaging.bitmap(flip)!.cgImage!, at: 0.2)
        let gifURL = try gif.finish(at: 0.7)
        let gifSource = CGImageSourceCreateWithURL(gifURL as CFURL, nil)!
        check(CGImageSourceGetCount(gifSource) == 2, "recorded GIF contains multiple decodable frames")
        let gifFrame = CGImageSourceCreateImageAtIndex(gifSource, 1, nil)!
        check(gifFrame.width == 80 && gifFrame.height == 40 && pixel(NSImage(cgImage: gifFrame,size: NSSize(width: 80,height: 40)),10,10) == "#0000FF", "GIF preserves frame size and changing content")
        let gifProperties = CGImageSourceCopyPropertiesAtIndex(gifSource, 1, nil)! as NSDictionary
        let gifDelay = (gifProperties[kCGImagePropertyGIFDictionary] as! NSDictionary)[kCGImagePropertyGIFDelayTime] as! Double
        check(abs(gifDelay - 0.5) < 0.02, "GIF holds final frame until recording stop time")
        let loop = (CGImageSourceCopyProperties(gifSource,nil)! as NSDictionary)[kCGImagePropertyGIFDictionary] as! NSDictionary
        check(loop[kCGImagePropertyGIFLoopCount] as? Int == 0, "GIF loops continuously")
        let gifData = try Data(contentsOf: gifURL)
        let clipboard = NSPasteboard.withUniqueName()
        try GIFMedia.copy(gifData, to: clipboard)
        check(clipboard.data(forType: GIFMedia.pasteboardType) == gifData, "GIF copy preserves original animated bytes")
        let attachment = URL(string: clipboard.string(forType: .fileURL)!)!
        let attachmentData = try Data(contentsOf: attachment)
        check(attachmentData == gifData, "GIF clipboard file attachment retains animation")
        clipboard.releaseGlobally(); try FileManager.default.removeItem(at: attachment)
        check(GIFMedia.poster(Data("not an image".utf8)) == nil, "GIF preview rejects corrupt media")
        let bounded = try GIFArchive(maxFrames: 2); defer { bounded.removeTemporaryFiles() }
        for time in [0.0, 0.1, 0.2] { try bounded.append(Imaging.bitmap(image)!.cgImage!, at: time) }
        check(bounded.atLimit && bounded.frames.count == 2, "GIF recording honors configured frame budget")
        _ = NSApplication.shared
        let animated = PinController(image: image); animated.setGIF(gifData)
        let pinRoot = FileManager.default.temporaryDirectory.appendingPathComponent("PromecaptGIFPinCheck-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: pinRoot) }
        let pinLibrary = try Library(root: pinRoot); try pinLibrary.savePins([animated])
        let restoredPins = try pinLibrary.restorePins()
        check(restoredPins.first?.0.animated == true && pinLibrary.gifData(for: restoredPins[0].0) == gifData, "GIF pin persists animated bytes across restart")
        try pinLibrary.savePins([], keeping: restoredPins.map { $0.0 })
        let deferredPins = try pinLibrary.restorePins()
        check(deferredPins.count == 1 && pinLibrary.gifData(for: deferredPins[0].0) == gifData, "startup restoration disabled preserves existing pin records and media")
        animated.replace(image); try pinLibrary.savePins([animated])
        check(!FileManager.default.fileExists(atPath: pinRoot.appendingPathComponent("pins/\(animated.id.uuidString).gif").path), "replacing GIF pin cleans old animation file")
        animated.close()
        let emptyGIF = try GIFArchive(); defer { emptyGIF.removeTemporaryFiles() }
        do { _ = try emptyGIF.finish(at: 1); check(false, "empty GIF must fail") }
        catch { check(true, "empty recording never produces a corrupt GIF") }
        let canvas = CanvasView(image: image)
        canvas.commit(flip)
        canvas.undoEdit()
        check(pixel(canvas.image, 10, 10) == "#FF0000", "undo restores pixels")
        canvas.redoEdit()
        check(pixel(canvas.image, 10, 10) == "#0000FF", "redo restores pixels")
        let pattern = Imaging.render(size: NSSize(width: 80, height: 40)) {
            NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 80, height: 40).fill()
            NSColor.black.setFill(); NSRect(x: 20, y: 10, width: 4, height: 20).fill()
        }
        for mosaic in [true, false] {
            let filtered = Imaging.filtered(pattern, rect: NSRect(x: 10, y: 5, width: 30, height: 30), mosaic: mosaic)
            check(pixel(filtered, 60, 20) == pixel(pattern, 60, 20), "\(mosaic ? "mosaic" : "blur") preserves outside region")
            check(Imaging.png(filtered) != Imaging.png(pattern), "\(mosaic ? "mosaic" : "blur") modifies selected region")
            let gentle = Imaging.filtered(pattern, rect: NSRect(x: 10, y: 5, width: 30, height: 30), mosaic: mosaic, strength: 3)
            let strong = Imaging.filtered(pattern, rect: NSRect(x: 10, y: 5, width: 30, height: 30), mosaic: mosaic, strength: 35)
            check(Imaging.png(gentle) != Imaging.png(strong), "\(mosaic ? "mosaic" : "blur") strength changes output pixels")
            check(pixel(strong, 60, 20) == pixel(pattern, 60, 20), "strong effect preserves pixels outside selection")
        }
        let adjustable = CanvasView(image: image)
        adjustable.tool = .rectangle
        adjustable.adjustParameter(by: 3)
        check(adjustable.lineWidth == 7, "shape wheel adjustment changes thickness")
        adjustable.adjustParameter(by: -100)
        check(adjustable.lineWidth == 1, "shape thickness cannot fall below one pixel")
        adjustable.tool = .conceal
        adjustable.adjustParameter(by: 3)
        check(adjustable.effectStrength == 20 && adjustable.lineWidth == 1, "conceal strength is independent of line thickness")
        adjustable.adjustParameter(by: 100)
        check(adjustable.effectStrength == 80, "conceal strength is bounded")
        adjustable.concealStyle = .blackbox
        adjustable.adjustParameter(by: -5)
        check(adjustable.effectStrength == 80 && !adjustable.parameterIsEnabled, "blackbox remains opaque without strength adjustment")
        let layered = CanvasView(image: pattern)
        layered.tool = .rectangle
        let shape = AnnotationObject(tool: .rectangle, points: [NSPoint(x: 10, y: 5), NSPoint(x: 40, y: 30)],
            color: AnnotationColor(.systemRed), lineWidth: 4, strength: 14, concealStyle: .mosaic)
        layered.addAnnotation(shape)
        check(layered.selectedID == nil && layered.document.objects.count == 1 && layered.tool == .rectangle, "drawing finishes without auto-selecting or changing the drawing tool")
        layered.tool = .select; layered.selectAnnotation(shape.id)
        check(layered.tool == .select && layered.effectiveTool == .rectangle, "selection mode stays active while shape properties are available")
        check(Imaging.png(layered.document.base) == Imaging.png(pattern), "drawing never changes the source pixels")
        let beforeMove = Imaging.png(layered.image)
        layered.moveSelection(dx: 12, dy: 3)
        check(layered.selectedAnnotation!.bounds.origin == NSPoint(x: 22, y: 8), "selected annotation moves independently")
        layered.undoEdit()
        check(Imaging.png(layered.image) == beforeMove, "undo restores annotation geometry and output")
        layered.redoEdit()
        check(layered.selectedAnnotation!.bounds.origin == NSPoint(x: 22, y: 8), "redo restores object move")
        layered.resizeSelection(to: NSRect(x: 5, y: 5, width: 60, height: 25))
        check(layered.selectedAnnotation!.bounds == NSRect(x: 5, y: 5, width: 60, height: 25), "selected annotation supports resize handles")
        layered.lineWidth = 9; layered.color = .systemBlue
        check(layered.selectedAnnotation!.lineWidth == 9 && layered.selectedAnnotation!.color == AnnotationColor(.systemBlue), "selected shape accepts thickness and color changes")
        check(!shape.contains(NSPoint(x: 25, y: 17), tolerance: 1) && shape.contains(NSPoint(x: 10, y: 17), tolerance: 2), "shape hit testing distinguishes stroke from empty center")
        layered.deleteSelection()
        check(layered.document.objects.isEmpty && Imaging.png(layered.image) == Imaging.png(pattern), "deleting an annotation restores original pixels")
        layered.undoEdit()
        check(layered.document.objects.count == 1, "undo restores a deleted object")
        let encodedObjects = try JSONEncoder().encode(layered.document.objects)
        let decodedObjects = try JSONDecoder().decode([AnnotationObject].self, from: encodedObjects)
        check(decodedObjects == layered.document.objects, "editable annotations survive JSON round trip")
        let cropDocument = layered.document.cropped(to: NSRect(x: 3, y: 4, width: 70, height: 32))
        check(cropDocument.base.size == NSSize(width: 70, height: 32) && cropDocument.objects[0].bounds.origin == NSPoint(x: 2, y: 1), "capture crop preserves editable objects in local coordinates")
        let masked = CanvasView(image: pattern)
        var effect = shape; effect.tool = .conceal; effect.strength = 3
        masked.addAnnotation(effect)
        masked.selectAnnotation(effect.id)
        let gentleMask = Imaging.png(masked.image)
        masked.effectStrength = 35
        check(Imaging.png(masked.image) != gentleMask, "existing mosaic strength can be edited after drawing")
        masked.moveSelection(dx: 30, dy: 0)
        check(pixel(masked.image, 20, 20) == pixel(pattern, 20, 20), "moving mosaic recomputes from source and restores uncovered pixels")
        masked.concealStyle = .blackbox
        check(masked.selectedAnnotation!.concealStyle == .blackbox, "existing conceal object can switch masking mode")
        let textCanvas = CanvasView(image: pattern)
        textCanvas.tool = .text
        textCanvas.beginText(at: NSPoint(x: 5, y: 5))
        textCanvas.activeTextInput?.stringValue = "한글 Promecapt"
        textCanvas.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification))
        check(textCanvas.activeTextInput != nil, "temporary text focus changes do not discard input")
        textCanvas.flushText()
        check(textCanvas.document.objects.first?.text == "한글 Promecapt" && textCanvas.document.objects.first?.tool == .text, "text input commits a selectable text object")
        let written = textCanvas.document.objects[0]
        textCanvas.beginText(at: written.bounds.origin, editing: written)
        textCanvas.activeTextInput?.stringValue = "수정한 글씨"
        textCanvas.flushText()
        check(textCanvas.document.objects.count == 1 && textCanvas.document.objects[0].text == "수정한 글씨", "editing text replaces the existing object without duplication")
        textCanvas.undoEdit()
        check(textCanvas.document.objects[0].text == "한글 Promecapt", "undo restores prior text content")
        let badges = CanvasView(image: pattern)
        badges.tool = .number
        badges.addNumber(at: NSPoint(x: 20, y: 20)); badges.addNumber(at: NSPoint(x: 60, y: 20))
        check(badges.document.objects.map(\.text) == ["1", "2"] && badges.nextNumber == 3, "number tool inserts consecutive circular badges")
        check(badges.document.objects[0].bounds.width == badges.document.objects[0].bounds.height, "number badge has circular geometry")
        let badgeData = try JSONEncoder().encode(badges.document.objects)
        let badgeObjects = try JSONDecoder().decode([AnnotationObject].self, from: badgeData)
        let reloadedBadges = CanvasView(image: pattern); reloadedBadges.load(AnnotationDocument(base: pattern, objects: badgeObjects))
        check(reloadedBadges.nextNumber == 3 && Imaging.png(reloadedBadges.image) == Imaging.png(badges.image), "number badges preserve appearance and next number after reload")
        check(badges.selectedID == nil, "consecutive number badges do not enter automatic resize mode")
        let ocrCanvas = CanvasView(image: image)
        ocrCanvas.tool = .rectangle
        var ocrSize = NSSize.zero
        ocrCanvas.beginOCRSelection(in: NSRect(x: 40, y: 0, width: 40, height: 40)) { ocrSize = $0.size }
        let ocrImage = ocrCanvas.completeOCRSelection(NSRect(x: 45, y: 5, width: 20, height: 20))!
        check(ocrSize == NSSize(width: 20, height: 20) && pixel(ocrImage, 10, 10) == "#0000FF", "OCR receives only the dragged image region")
        check(!ocrCanvas.isSelectingOCR && ocrCanvas.tool == .rectangle && ocrCanvas.document.objects.isEmpty, "OCR region selection preserves drawing mode and document")
        ocrCanvas.beginOCRSelection(in: NSRect(x: 40, y: 0, width: 40, height: 40)) { ocrSize = $0.size }
        let boundedOCR = ocrCanvas.completeOCRSelection(NSRect(x: 0, y: 0, width: 80, height: 40))!
        check(boundedOCR.size == NSSize(width: 40, height: 40), "OCR selection cannot escape the capture area")
        ocrCanvas.beginOCRSelection { ocrSize = $0.size }
        check(ocrCanvas.completeOCRSelection(NSRect(x: 0, y: 0, width: 1, height: 1)) == nil && ocrCanvas.isSelectingOCR, "tiny OCR selection allows retry without closing capture")
        check(ocrCanvas.cancelInteraction() && !ocrCanvas.isSelectingOCR && Imaging.png(ocrCanvas.image) == Imaging.png(image), "cancelling OCR selection preserves source image")
        var selection = CaptureSelection(bounds: NSRect(x: 0, y: 0, width: 800, height: 600))
        selection.begin(at: NSPoint(x: 200, y: 150))
        selection.update(to: NSPoint(x: 100, y: 50))
        check(selection.rect == NSRect(x: 100, y: 50, width: 100, height: 100), "reverse direction selection")
        check(selection.pixelRect(imageSize: NSSize(width: 1600, height: 1200)) == NSRect(x: 200, y: 100, width: 200, height: 200), "Retina selection conversion")
        selection.begin(at: NSPoint(x: 150, y: 100))
        selection.update(to: NSPoint(x: 790, y: 590))
        check(selection.rect == NSRect(x: 700, y: 500, width: 100, height: 100), "moving selection clamps to screen")
        selection.begin(at: NSPoint(x: 700, y: 500))
        selection.update(to: NSPoint(x: 650, y: 450))
        check(selection.rect == NSRect(x: 650, y: 450, width: 150, height: 150), "resize keeps opposite corner fixed")
        selection.nudge(dx: -0.5, dy: 0.5, resize: false)
        check(selection.rect.minX == 649.5 && selection.rect.minY == 450, "single pixel move at display edge")
        selection.nudge(dx: -1, dy: -1, resize: true)
        check(selection.rect.size == NSSize(width: 149, height: 149), "keyboard resizes selection")
        check(CaptureSelection.Handle.allCases.allSatisfy { selection.handle(at: selection.point(for: $0)) == $0 }, "all eight resize handles")
        check(ImageKeyboardCommand.resolve(keyCode: 8, flags: .command) == .copy, "Cmd-C uses hardware C key independently of input language")
        check(ImageKeyboardCommand.resolve(keyCode: 6, flags: [.command,.shift]) == .redo, "Cmd-Shift-Z resolves redo")
        check(ImageKeyboardCommand.resolve(keyCode: 8, flags: []) == nil, "plain typing does not trigger copy")
        let privateBoard = NSPasteboard(name: NSPasteboard.Name("PromecaptChecks-\(UUID().uuidString)"))
        check(copyImage(image, to: privateBoard), "image clipboard write succeeds")
        check(privateBoard.types?.contains(.png) == true && privateBoard.types?.contains(.tiff) == true, "clipboard advertises PNG and TIFF")
        let pasted = NSImage(pasteboard: privateBoard)!
        check(Imaging.bitmap(pasted)!.pixelsWide == 80 && Imaging.bitmap(pasted)!.pixelsHigh == 40, "clipboard round trip preserves selected dimensions")
        check(pixel(pasted, 10, 10) == "#FF0000", "clipboard preserves image pixels")
        privateBoard.releaseGlobally()
        let custom = Shortcut(keyCode: 12, flags: [.control,.option,.shift,.command])
        check(custom.display == "⌃⌥⇧⌘Q", "custom shortcut displays all modifiers")
        check(custom.carbonModifiers != 0 && custom.isValid, "custom shortcut converts to global registration modifiers")
        check(!Shortcut(keyCode: 8, flags: []).isValid, "unmodified typing cannot become a global shortcut")
        check(!Shortcut(keyCode: 8, flags: .command).isValid, "global shortcuts cannot swallow standard Cmd-C")
        let f1 = Shortcut.functionKey(1)!
        check(f1.keyCode == 122 && f1.modifiers == 0 && f1.display == "F1" && f1.isValid, "F1 picker creates a bare F1 binding")
        check(Shortcut(keyCode: 122, flags: [.function]) == f1, "Fn modifier does not turn F1 into a different shortcut")
        check(Set((1...20).compactMap(Shortcut.functionKey)).count == 20 && (1...20).allSatisfy { Shortcut.functionKey($0)!.isValid }, "all twenty function keys are unique valid bindings")
        check(Shortcut.functionKey(0) == nil && Shortcut.functionKey(21) == nil, "function key picker rejects invalid choices")
        check(ShortcutPreferences.duplicate(in: [.capture: custom, .paste: custom]) != nil, "duplicate shortcuts are rejected")
        let oldProfile = UserDefaults.standard.object(forKey: "hotkeyProfile")
        let oldCustom = UserDefaults.standard.object(forKey: ShortcutPreferences.customKey)
        ShortcutPreferences.saveCustom([.capture: custom])
        check(ShortcutPreferences.bindings()[.capture] == custom && ShortcutPreferences.bindings()[.paste] == nil, "custom shortcuts survive persistence and preserve disabled actions")
        UserDefaults.standard.set(oldProfile, forKey: "hotkeyProfile")
        UserDefaults.standard.set(oldCustom, forKey: ShortcutPreferences.customKey)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PromecaptChecks-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: "historyLimit")
        defer { defaults.set(previous, forKey: "historyLimit") }
        defaults.set(2, forKey: "historyLimit")
        let library = try Library(root: root)
        let pinRecord = PinRecord(id: UUID(), x: 0, y: 0, width: 80, height: 40, opacity: 1, group: "", annotations: layered.document.objects)
        try Imaging.png(layered.document.base)!.write(to: root.appendingPathComponent("pins/\(pinRecord.id.uuidString)-base.png"))
        let restoredDocument = library.annotationDocument(for: pinRecord)
        check(restoredDocument?.objects == layered.document.objects && Imaging.png(restoredDocument!.rendered()) == Imaging.png(layered.image), "pin metadata reload preserves selectable objects and output")
        var legacyRecord = pinRecord; legacyRecord.annotations = nil
        let legacyData = try JSONEncoder().encode(legacyRecord)
        let legacyDecoded = try JSONDecoder().decode(PinRecord.self, from: legacyData)
        check(legacyDecoded.annotations == nil && library.annotationDocument(for: legacyDecoded) == nil, "legacy bitmap pins remain compatible without annotation metadata")
        let first = try library.add(image)
        try library.add(image)
        let last = try library.add(flip)
        check(library.entries.count == 2 && library.entries.first?.id == last.id, "history retention")
        check(!FileManager.default.fileExists(atPath: library.historyURL(first).path), "expired image removal")
        let reload = try Library(root: root)
        check(reload.entries.first?.id == last.id && reload.image(last) != nil, "history survives reload")
        try reload.clearHistory()
        let empty = try Library(root: root)
        check(empty.entries.isEmpty, "clear history persists")
        print("\(count) checks passed")
        if let index = CommandLine.arguments.firstIndex(of: "--fixture"), CommandLine.arguments.count > index + 1 {
            let demo = Imaging.render(size: NSSize(width: 960, height: 540)) {
                NSColor(calibratedRed: 0.06, green: 0.1, blue: 0.16, alpha: 1).setFill()
                NSRect(x: 0, y: 0, width: 960, height: 540).fill()
                ("promepaste" as NSString).draw(at: NSPoint(x: 60, y: 340), withAttributes: [
                    .font: NSFont.systemFont(ofSize: 72, weight: .bold), .foregroundColor: NSColor.white])
                ("Capture. Annotate. Pin." as NSString).draw(at: NSPoint(x: 64, y: 270), withAttributes: [
                    .font: NSFont.systemFont(ofSize: 32), .foregroundColor: NSColor.systemMint])
                ("Built for your everyday work." as NSString).draw(at: NSPoint(x: 64, y: 100), withAttributes: [
                    .font: NSFont.systemFont(ofSize: 24), .foregroundColor: NSColor.lightGray])
            }
            try Imaging.png(demo)!.write(to: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
        }
    }
}
