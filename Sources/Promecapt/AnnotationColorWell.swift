import AppKit

/// Keep the shared color panel above full-screen capture and pin-edit windows.
final class AnnotationColorWell: NSColorWell {
    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) }
    private var originalAccessory: NSView?
    private var originalLevel: NSWindow.Level?
    private var originalBehavior: NSWindow.CollectionBehavior?
    private var originalHidesOnDeactivate = false
    private weak var owner: NSWindow?
    private var closeObserver: NSObjectProtocol?

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if originalLevel != nil, newWindow !== window { deactivate() }
        super.viewWillMove(toWindow: newWindow)
    }
    override func mouseDown(with event: NSEvent) { activate(true) }
    override func activate(_ exclusive: Bool) {
        super.activate(exclusive)
        guard let window else { return }
        let panel = NSColorPanel.shared
        if originalLevel == nil {
            originalAccessory = panel.accessoryView
            originalLevel = panel.level
            originalBehavior = panel.collectionBehavior
            originalHidesOnDeactivate = panel.hidesOnDeactivate
        }
        if panel.parent !== window {
            panel.parent?.removeChildWindow(panel)
            window.addChildWindow(panel, ordered: .above)
        }
        owner = window
        panel.level = NSWindow.Level(rawValue: window.level.rawValue + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.accessoryView = confirmationAccessory()
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in self?.deactivate() }
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }
    func confirmationAccessory() -> NSView {
        let footer = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 42))
        let apply = NSButton(title: L("확인"), target: self, action: #selector(confirmColor))
        apply.identifier = .init("confirm-color")
        apply.bezelStyle = .rounded
        apply.keyEquivalent = "\r"
        apply.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(apply)
        NSLayoutConstraint.activate([
            apply.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -12),
            apply.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
            apply.widthAnchor.constraint(greaterThanOrEqualToConstant: 72)])
        return footer
    }
    @objc private func confirmColor() {
        let parent = owner
        _ = sendAction(action, to: target)
        deactivate()
        parent?.makeKeyAndOrderFront(nil)
    }
    override func deactivate() {
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        closeObserver = nil
        if let level = originalLevel {
            let panel = NSColorPanel.shared
            owner?.removeChildWindow(panel)
            panel.orderOut(nil)
            panel.accessoryView = originalAccessory
            panel.level = level
            if let originalBehavior { panel.collectionBehavior = originalBehavior }
            panel.hidesOnDeactivate = originalHidesOnDeactivate
        }
        originalAccessory = nil
        originalLevel = nil; originalBehavior = nil; owner = nil
        super.deactivate()
    }
    deinit { if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) } }
}
