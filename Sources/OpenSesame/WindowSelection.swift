import AppKit
import ApplicationServices

enum WindowSelection {
    /// The scheduler runs on the main queue in production. Tests supply a
    /// deterministic queue; neither path retries activation or posts input.
    static func waitForFocus(isCurrent: @escaping () -> Bool, focused: @escaping () -> Bool,
                             schedule: (TimeInterval, @escaping () -> Void) -> Void = { delay, work in
                                 DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
                             }, refresh: @escaping () -> Void, unavailable: @escaping () -> Void) {
        var finished = false
        for delay in [0.15, 0.35, 0.7, 1.2] {
            schedule(delay) {
                guard !finished, isCurrent() else { return }
                if focused() { finished = true; refresh() }
                else if delay == 1.2 { finished = true; unavailable() }
            }
        }
    }
    static func isFocused(_ window: StackWindowResolver.Resolved,
                          frontOwner: pid_t? = NSWorkspace.shared.frontmostApplication?.processIdentifier,
                          read: (AXUIElement, String) -> CFTypeRef? = attribute) -> Bool {
        guard frontOwner == window.owner else { return false }
        let app = AXUIElementCreateApplication(window.owner)
        AXUIElementSetMessagingTimeout(app, 0.08)
        guard let focused = read(app, kAXFocusedWindowAttribute) else { return false }
        return CFEqual(focused, window.element)
    }
}
