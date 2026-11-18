import AppKit

extension AppDelegate {
    @objc func pastePin() {
        let pasteboard = NSPasteboard.general
        if let data = pasteboard.data(forType: NSPasteboard.PasteboardType("com.compuserve.gif")), let image = GIFMedia.poster(data) {
            createPin(image).setGIF(data); return
        }
        if let image = NSImage(pasteboard: pasteboard) { _ = createPin(Imaging.normalized(image)); return }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           let url = urls.first, url.isFileURL, let image = NSImage(contentsOf: url) {
            _ = createPin(Imaging.normalized(image)); return
        }
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            // Text and color cards are drawn at point size, so they keep one pixel per point.
            _ = createPin(Imaging.parseColor(text).map(Imaging.colorImage) ?? Imaging.textImage(String(text.prefix(8000))), pixelScale: 1)
            return
        }
        showError(L("클립보드에 이미지 또는 텍스트를 복사한 후 다시 시도해 주세요."))
    }

    @discardableResult func createPin(_ image: NSImage, id: UUID = UUID(), pixelScale: CGFloat? = nil) -> PinController {
        let pin = PinController(image: image, id: id, pixelScale: pixelScale)
        pin.onChange = { [weak self] in self?.schedulePersistence() }
        pin.onClose = { [weak self] closing in
            self?.pins.removeAll { $0 === closing }
            self?.schedulePersistence()
        }
        pin.onEdit = { [weak self] image in self?.edit(image) }
        pin.onDrop = { [weak self] image in self?.createPin(image) }
        pins.append(pin)
        pin.show()
        hidden = false
        schedulePersistence()
        return pin
    }

    func edit(_ image: NSImage) {
        let editor = EditorController(image: image)
        editor.onPin = { [weak self] document in
            self?.createPin(document.rendered()).setDocument(document)
        }
        editor.onClose = { [weak self] closing in self?.editors.removeAll { $0 === closing } }
        editors.append(editor)
        editor.show()
    }

    func restore(_ records: [PinRecord]) {
        for record in records {
            guard let image = library.pinImage(for: record) else { continue }
            let pin = createPin(image, id: record.id)
            if let gif = library.gifData(for: record) { pin.setGIF(gif) }
            else if let document = library.annotationDocument(for: record) { pin.setDocument(document) }
            var frame = NSRect(x: record.x, y: record.y, width: max(32, record.width), height: max(32, record.height))
            if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) {
                frame.origin = NSScreen.main?.visibleFrame.origin ?? .zero
            }
            pin.window?.setFrame(frame, display: true)
            pin.window?.alphaValue = min(1, max(0.15, record.opacity))
            pin.group = record.group
        }
    }

    /// Pins kept from earlier sessions while startup restoration is off.
    @objc func restoreDeferredPins() {
        let records = deferredPinRecords
        deferredPinRecords = []
        restore(records)
        schedulePersistence()
    }
    @objc func discardDeferredPins() {
        guard !deferredPinRecords.isEmpty else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L("이전 고정 이미지 {0}개를 지울까요?", deferredPinRecords.count)
        alert.informativeText = L("복원하지 않은 이전 세션의 고정 이미지가 삭제됩니다.")
        alert.addButton(withTitle: L("취소"))
        alert.addButton(withTitle: L("모두 지우기"))
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        let previous = deferredPinRecords
        deferredPinRecords = []
        persistTask?.cancel()
        do { try library.savePins(pins, keeping: []) }
        catch { deferredPinRecords = previous; showError(L("고정 이미지 저장 실패: {0}", error.localizedDescription)) }
    }

    func schedulePersistence() {
        persistTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }
            do { try self.library.savePins(self.pins, keeping: self.deferredPinRecords) }
            catch { showError(L("고정 이미지 저장 실패: {0}", error.localizedDescription)) }
        }
        persistTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: task)
    }

    @objc func togglePins() {
        hidden.toggle()
        for pin in pins { if hidden { pin.window?.orderOut(nil) } else { pin.show() } }
    }
    @objc func toggleGroup(_ sender: NSMenuItem) {
        guard let group = sender.representedObject as? String else { return }
        let selected = pins.filter { $0.group == group }
        let visible = selected.contains { $0.window?.isVisible == true }
        for pin in selected { if visible { pin.window?.orderOut(nil) } else { pin.show() } }
    }
    @objc func recoverPins() {
        for pin in pins { pin.window?.ignoresMouseEvents = false; pin.window?.alphaValue = 1; pin.show() }
        hidden = false
        schedulePersistence()
    }
}
