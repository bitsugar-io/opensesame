import Foundation
import CoreGraphics
import OpenSesameCore

/// Owns the only blocking input tap. Its run loop is independent of UI, AX and drawing.
final class KeyboardHook {
    private let lock = NSLock()
    private var routing = KeyboardRouting()
    private var tap: CFMachPort?
    private var mouseTap: CFMachPort?
    private var runLoop: CFRunLoop?
    private var stopped = false
    let handle: (CGEvent, UUID?) -> Void
    let cancel: (String) -> Void
    let installed: (Bool) -> Void
    let disabled: () -> Void
    init(handle: @escaping (CGEvent, UUID?) -> Void, cancel: @escaping (String) -> Void, installed: @escaping (Bool) -> Void, disabled: @escaping () -> Void) {
        self.handle = handle; self.cancel = cancel; self.installed = installed; self.disabled = disabled
    }
    func update(_ snapshot: KeyboardRouting.Snapshot) {
        lock.lock(); routing.update(snapshot, now: ProcessInfo.processInfo.systemUptime); lock.unlock()
    }
    func disarm() { lock.lock(); routing.disarm(); lock.unlock() }
    func start() {
        let thread = Thread { [self] in
            let mask = CGEventMask(1) << CGEventType.keyDown.rawValue
            let eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                return Unmanaged<KeyboardHook>.fromOpaque(context).takeUnretainedValue().receive(type, event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque())
            guard let eventTap else { DispatchQueue.main.async { self.installed(false) }; return }
            let mouseMask = (CGEventMask(1) << CGEventType.leftMouseDown.rawValue) | (CGEventMask(1) << CGEventType.rightMouseDown.rawValue) | (CGEventMask(1) << CGEventType.scrollWheel.rawValue)
            // Listen-only taps cannot suppress or delay mouse delivery.
            let mouseObserver = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: mouseMask, callback: { _, type, event, context in
                if let context {
                    Unmanaged<KeyboardHook>.fromOpaque(context).takeUnretainedValue().observeMouse(type, event)
                }
                return Unmanaged.passUnretained(event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque())
            guard let mouseObserver else {
                CFMachPortInvalidate(eventTap)
                DispatchQueue.main.async { self.installed(false) }
                return
            }
            let loop = CFRunLoopGetCurrent()!
            lock.lock(); tap = eventTap; mouseTap = mouseObserver; runLoop = loop; let shouldStop = stopped; lock.unlock()
            guard !shouldStop else { CFMachPortInvalidate(eventTap); CFMachPortInvalidate(mouseObserver); return }
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(loop, source, .commonModes)
            let mouseSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, mouseObserver, 0)
            CFRunLoopAddSource(loop, mouseSource, .commonModes)
            CGEvent.tapEnable(tap: mouseObserver, enable: true)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            DispatchQueue.main.async { self.installed(true) }
            CFRunLoopRun()
            CFMachPortInvalidate(eventTap)
            CFMachPortInvalidate(mouseObserver)
        }
        thread.name = "OpenSesame keyboard hook"
        thread.qualityOfService = .userInteractive
        thread.start()
    }
    func observeMouse(_ type: CGEventType, _ event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
            disarm(); DispatchQueue.main.async { self.disabled() }
            return
        }
        guard event.getIntegerValueField(.eventSourceUserData) != 0x4F534D45 else { return }
        // Release capture on this input thread before waiting for UI dismissal.
        var session = true
        if lock.try() { session = routing.mouse(at: event.location); lock.unlock() }
        if session { DispatchQueue.main.async { self.cancel("mouse-or-scroll") } }
    }
    func receive(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // Leave the tap disabled: repeatedly reenabling a slow tap can
            // repeatedly interrupt input. Mouse events never enter this tap.
            disarm(); DispatchQueue.main.async { self.disabled() }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown, event.getIntegerValueField(.eventSourceUserData) != 0x4F534D45 else { return Unmanaged.passUnretained(event) }
        // Never wait for a state update while holding up system input.
        guard lock.try() else { return Unmanaged.passUnretained(event) }
        let flags = event.flags
        let modifiers = Set([("control", CGEventFlags.maskControl), ("shift", .maskShift), ("option", .maskAlternate), ("command", .maskCommand)].compactMap { flags.contains($0.1) ? $0.0 : nil })
        // AppKit's keyboard-layout translation can assert when called off the
        // main thread. Read the event payload directly; empty payloads use the
        // main-thread layout cache already held by the routing snapshot.
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 8)
        event.keyboardGetUnicodeString(maxStringLength: buffer.count, actualStringLength: &length, unicodeString: &buffer)
        let text = String(utf16CodeUnits: buffer, count: min(length, buffer.count))
        let decision = routing.route(key: Int(event.getIntegerValueField(.keyboardEventKeycode)), modifiers: modifiers, text: text,
                                     repeating: event.getIntegerValueField(.keyboardEventAutorepeat) != 0, now: ProcessInfo.processInfo.systemUptime)
        lock.unlock()
        switch decision {
        case .pass: return Unmanaged.passUnretained(event)
        case .consume: return nil
        case .cancelAndPass:
            DispatchQueue.main.async { self.cancel("input-heartbeat-expired") }
            return Unmanaged.passUnretained(event)
        case .handle(let consume, let generation):
            guard let copy = event.copy() else { return Unmanaged.passUnretained(event) }
            DispatchQueue.main.async { self.handle(copy, generation) }
            return consume ? nil : Unmanaged.passUnretained(event)
        }
    }
    func stop() {
        lock.lock(); stopped = true; let tap = tap, mouseTap = mouseTap, loop = runLoop; lock.unlock()
        if let tap { CFMachPortInvalidate(tap) }
        if let mouseTap { CFMachPortInvalidate(mouseTap) }
        if let loop { CFRunLoopStop(loop) }
    }
}
