import AppKit
import Carbon
import ApplicationServices

enum HotkeyAction: Int, CaseIterable, Codable {
    case capture = 1, paste, toggle, settings
    var title: String {
        switch self {
        case .capture: return L("영역 캡처")
        case .paste: return L("클립보드 고정")
        case .toggle: return L("고정 이미지 표시 / 숨기기")
        case .settings: return L("설정 창")
        }
    }
}

struct Shortcut: Codable, Equatable, Hashable {
    let keyCode: UInt16
    let modifiers: UInt
    static let allowedModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
    static func functionKey(_ number: Int) -> Shortcut? {
        let codes: [UInt16] = [122,120,99,118,96,97,98,100,101,109,103,111,105,107,113,106,64,79,80,90]
        guard (1...codes.count).contains(number) else { return nil }
        return Shortcut(keyCode: codes[number - 1], flags: [])
    }
    init(keyCode: UInt16, flags: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        modifiers = flags.intersection(Self.allowedModifiers).rawValue
    }
    var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }
    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
    var isValid: Bool {
        // A global binding must not swallow the copy/paste/edit keys used inside capture.
        if flags == .command && [UInt16(0),1,6,7,8,9,12,13,43].contains(keyCode) { return false }
        let functions: Set<UInt16> = [122,120,99,118,96,97,98,100,101,109,103,111,105,107,113,106,64,79,80,90]
        return functions.contains(keyCode) || !flags.intersection([.command, .control, .option]).isEmpty
    }
    var display: String {
        var prefix = ""
        if flags.contains(.control) { prefix += "⌃" }
        if flags.contains(.option) { prefix += "⌥" }
        if flags.contains(.shift) { prefix += "⇧" }
        if flags.contains(.command) { prefix += "⌘" }
        let names: [UInt16: String] = [0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",11:"B",12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",18:"1",19:"2",20:"3",21:"4",22:"6",23:"5",24:"=",25:"9",26:"7",27:"−",28:"8",29:"0",30:"]",31:"O",32:"U",33:"[",34:"I",35:"P",36:"↩",37:"L",38:"J",39:"'",40:"K",41:";",42:"\\",43:",",44:"/",45:"N",46:"M",47:".",48:"⇥",49:"Space",50:"`",51:"⌫",53:"Esc",65:".",67:"*",69:"+",75:"/",76:"⌤",78:"−",81:"=",82:"0",83:"1",84:"2",85:"3",86:"4",87:"5",88:"6",89:"7",91:"8",92:"9",122:"F1",120:"F2",99:"F3",118:"F4",96:"F5",97:"F6",98:"F7",100:"F8",101:"F9",109:"F10",103:"F11",111:"F12",105:"F13",107:"F14",113:"F15",106:"F16",64:"F17",79:"F18",80:"F19",90:"F20",115:"↖",116:"Page Up",117:"⌦",119:"↘",121:"Page Down",123:"←",124:"→",125:"↓",126:"↑"]
        return prefix + (names[keyCode] ?? "Key \(keyCode)")
    }
}

enum ShortcutPreferences {
    static let customKey = "customHotkeys.v1"
    static func bindings(profile: Int? = nil) -> [HotkeyAction: Shortcut] {
        let profile = profile ?? UserDefaults.standard.integer(forKey: "hotkeyProfile")
        switch profile {
        case 0: return [.capture: Shortcut(keyCode: 122, flags: []), .paste: Shortcut(keyCode: 99, flags: []), .toggle: Shortcut(keyCode: 118, flags: [])]
        case 2: return [:]
        case 3:
            guard let data = UserDefaults.standard.data(forKey: customKey),
                  let saved = try? JSONDecoder().decode([String: Shortcut].self, from: data) else { return [:] }
            return Dictionary(uniqueKeysWithValues: saved.compactMap { key, value in
                guard let id = Int(key), let action = HotkeyAction(rawValue: id) else { return nil }
                return (action, value)
            })
        default: return [.capture: Shortcut(keyCode: 18, flags: [.command,.option]), .paste: Shortcut(keyCode: 20, flags: [.command,.option]), .toggle: Shortcut(keyCode: 21, flags: [.command,.option])]
        }
    }
    static func saveCustom(_ bindings: [HotkeyAction: Shortcut]) {
        let values = Dictionary(uniqueKeysWithValues: bindings.map { (String($0.key.rawValue), $0.value) })
        if let data = try? JSONEncoder().encode(values) {
            UserDefaults.standard.set(data, forKey: customKey)
            UserDefaults.standard.set(3, forKey: "hotkeyProfile")
        }
    }
    static func duplicate(in bindings: [HotkeyAction: Shortcut]) -> HotkeyAction? {
        var seen = Set<Shortcut>()
        for action in HotkeyAction.allCases {
            if let binding = bindings[action], !seen.insert(binding).inserted { return action }
        }
        return nil
    }
}

final class Hotkeys {
    private var references: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private var keyTap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var bindings: [HotkeyAction: Shortcut] = [:]
    private var pressedKeys = Set<UInt16>()
    var action: ((UInt32) -> Void)?

    // Match only configured shortcuts, before the foreground app can consume F keys.
    // Carbon remains the permission-free path when Accessibility is unavailable.
    private func installKeyTap() {
        guard AXIsProcessTrusted(), !bindings.isEmpty else { return }
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue) | (CGEventMask(1) << CGEventType.keyUp.rawValue)
        keyTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let owner = Unmanaged<Hotkeys>.fromOpaque(context).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = owner.keyTap { CGEvent.tapEnable(tap: tap, enable: true) }
                    owner.pressedKeys.removeAll()
                    return Unmanaged.passUnretained(event)
                }
                let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                if type == .keyUp {
                    return owner.pressedKeys.remove(code) != nil ? nil : Unmanaged.passUnretained(event)
                }
                let shortcut = Shortcut(keyCode: code, flags: NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue)))
                guard !ShortcutRecorder.isRecordingShortcut,
                      let action = owner.bindings.first(where: { $0.value == shortcut })?.key else {
                    return Unmanaged.passUnretained(event)
                }
                if owner.pressedKeys.insert(code).inserted {
                    // Never activate a capture window inside the synchronous event tap callback.
                    DispatchQueue.main.async { [weak owner] in owner?.action?(UInt32(action.rawValue)) }
                }
                return nil
            }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        if let keyTap {
            tapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, keyTap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), tapSource, .commonModes)
            CGEvent.tapEnable(tap: keyTap, enable: true)
        }
    }
    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var key = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &key)
            guard status == noErr, key.signature == 0x50524D50 else { return OSStatus(eventNotHandledErr) }
            Unmanaged<Hotkeys>.fromOpaque(context).takeUnretainedValue().action?(key.id)
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func unregisterAll() {
        if let keyTap { CGEvent.tapEnable(tap: keyTap, enable: false); CFMachPortInvalidate(keyTap) }
        if let tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes) }
        keyTap = nil; tapSource = nil; bindings = [:]; pressedKeys.removeAll()
        for ref in references { UnregisterEventHotKey(ref) }
        references.removeAll()
    }
    /// Transaction owner restores previous bindings on failure; no partially registered set remains.
    func register(_ bindings: [HotkeyAction: Shortcut]) -> String? {
        unregisterAll()
        if let duplicate = ShortcutPreferences.duplicate(in: bindings) { return L("{0}: 다른 기능과 단축키가 겹칩니다.", duplicate.title) }
        for action in HotkeyAction.allCases {
            guard let shortcut = bindings[action] else { continue }
            guard shortcut.isValid else { unregisterAll(); return L("{0}: 기능키 또는 ⌘·⌥·⌃를 포함한 조합을 지정하세요.", action.title) }
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(UInt32(shortcut.keyCode), shortcut.carbonModifiers,
                EventHotKeyID(signature: 0x50524D50, id: UInt32(action.rawValue)), GetApplicationEventTarget(), 0, &ref)
            guard status == noErr, let ref else {
                unregisterAll()
                return L("{0} {1}: 시스템 또는 다른 앱에서 사용 중입니다. ({2})", action.title, shortcut.display, status)
            }
            references.append(ref)
        }
        self.bindings = bindings
        installKeyTap()
        return nil
    }
    deinit { unregisterAll(); if let handler { RemoveEventHandler(handler) } }
}
