import Carbon
import Foundation
import OpenSesameCore

/// Input-source APIs are main-thread-only. The input thread uses an immutable
/// lookup and never asks AppKit or the input-source manager to translate a key.
enum KeyboardCharacters {
    static let sourceChanged = Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)
    static func current() -> [Int: String] {
        precondition(Thread.isMainThread)
        guard let reference = TISCopyCurrentKeyboardLayoutInputSource() else { return [:] }
        let source = reference.takeRetainedValue()
        guard let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return [:] }
        let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return [:] }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        var result: [Int: String] = [:]
        for code in 0..<128 {
            var deadKeyState: UInt32 = 0
            var length = 0
            var buffer = [UniChar](repeating: 0, count: 8)
            let status = UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDown), 0, UInt32(LMGetKbdType()),
                OptionBits(1 << kUCKeyTranslateNoDeadKeysBit), &deadKeyState, buffer.count, &length, &buffer)
            guard status == noErr else { continue }
            let text = String(utf16CodeUnits: buffer, count: min(length, buffer.count))
            if let character = Hints.inputCharacter(text) { result[code] = character }
        }
        return result
    }
}
