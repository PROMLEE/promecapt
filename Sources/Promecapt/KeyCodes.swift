/// Virtual key codes reported by `NSEvent.keyCode` (macOS ANSI layout).
enum KeyCode {
    static let s: UInt16 = 1, z: UInt16 = 6, c: UInt16 = 8, o: UInt16 = 31, h: UInt16 = 4, p: UInt16 = 35
    static let returnKey: UInt16 = 36, space: UInt16 = 49, escape: UInt16 = 53, keypadEnter: UInt16 = 76
    static let deleteKey: UInt16 = 51, forwardDelete: UInt16 = 117, tab: UInt16 = 48, comma: UInt16 = 43, period: UInt16 = 47
    static let left: UInt16 = 123, right: UInt16 = 124, down: UInt16 = 125, up: UInt16 = 126
}
