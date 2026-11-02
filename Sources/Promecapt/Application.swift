import AppKit

@objc(PromecaptApplication)
final class PromecaptApplication: NSApplication {
    override func sendEvent(_ event: NSEvent) {
        ShortcutRecorder.cancelIfClickedOutside(event)
        if ShortcutRecorder.activeRecorder?.record(event) == true { return }
        // Carbon handles keys while another app is active. App-directed key events also
        // need the same behavior while one of our windows is active (including AX input).
        if event.type == .keyDown, !event.isARepeat, !ShortcutRecorder.isRecordingShortcut {
            let shortcut = Shortcut(keyCode: event.keyCode, flags: event.modifierFlags)
            if let action = ShortcutPreferences.bindings().first(where: { $0.value == shortcut })?.key {
                (delegate as? AppDelegate)?.executeHotkey(UInt32(action.rawValue))
                return
            }
        }
        super.sendEvent(event)
    }
}
