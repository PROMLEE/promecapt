import AppKit

/// Keep the shared color panel above full-screen capture and pin-edit windows.
final class AnnotationColorWell: NSColorWell {
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
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in self?.deactivate() }
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }
    override func deactivate() {
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        closeObserver = nil
        if let level = originalLevel {
            let panel = NSColorPanel.shared
            owner?.removeChildWindow(panel)
            panel.orderOut(nil)
            panel.level = level
            if let originalBehavior { panel.collectionBehavior = originalBehavior }
            panel.hidesOnDeactivate = originalHidesOnDeactivate
        }
        originalLevel = nil; originalBehavior = nil; owner = nil
        super.deactivate()
    }
    deinit { if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) } }
}
