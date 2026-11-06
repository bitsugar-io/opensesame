import AppKit
import OpenSesameCore
import Testing
@testable import OpenSesame

@MainActor
struct KeyboardHookTests {
    /// Exercise callbacks only. No OS event tap is installed and no input is posted.
    @Test func callbackReturnsWhileTheUIThreadIsWaitingAndMouseReleasesCapture() throws {
        _ = NSApplication.shared
        var delivered = 0
        let hook = KeyboardHook(handle: { _, _ in delivered += 1 }, cancel: { _ in }, installed: { _ in }, disabled: {}, now: { 0 })
        hook.update(.init(generation: UUID(), shortcut: Shortcut(), enabled: true, recording: false, active: true, pending: false, labels: ["am"]))
        let key = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true))
        var character: UniChar = 97
        key.keyboardSetUnicodeString(stringLength: 1, unicodeString: &character)
        let mouse = try #require(CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: .zero, mouseButton: .left))
        let outcome = Outcome()
        let completed = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            let consumed = hook.receive(.keyDown, key) == nil
            hook.observeMouse(.leftMouseDown, mouse)
            let passedAfterClick = hook.receive(.keyDown, key) != nil
            outcome.set(consumed && passedAfterClick)
            completed.signal()
        }
        // Waiting here deliberately prevents any main-queue handler from running.
        #expect(completed.wait(timeout: .now() + 0.5) == .success)
        #expect(outcome.get())
        #expect(delivered == 0)
    }
}

private final class Outcome: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func set(_ value: Bool) { lock.lock(); self.value = value; lock.unlock() }
    func get() -> Bool { lock.lock(); defer { lock.unlock() }; return value }
}

@MainActor
struct KeyboardHookEmptyPayloadTests {
    @Test func emptyUnicodePayloadUsesCachedLayoutWithoutCallingAppKitOnInputThread() throws {
        let hook = KeyboardHook(handle: { _, _ in }, cancel: { _ in }, installed: { _ in }, disabled: {}, now: { 0 })
        hook.update(.init(generation: UUID(), shortcut: Shortcut(), enabled: true, recording: false, active: true, pending: false, labels: ["am"], keyCharacters: [0: "a"]))
        let key = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true))
        var empty: UniChar = 0
        key.keyboardSetUnicodeString(stringLength: 0, unicodeString: &empty)
        let outcome = Outcome()
        let completed = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            outcome.set(hook.receive(.keyDown, key) == nil)
            completed.signal()
        }
        #expect(completed.wait(timeout: .now() + 0.5) == .success)
        #expect(outcome.get())
    }
}
