import Foundation
import Testing
@testable import OpenSesameCore

private func state(_ generation: UUID = UUID(), active: Bool = true, pending: Bool = false, recording: Bool = false) -> KeyboardRouting.Snapshot {
    .init(generation: generation, shortcut: Shortcut(), enabled: true, recording: recording, active: active, pending: pending, labels: ["am", "av"])
}
@Test func unresponsiveUIReleasesKeyboardAndLateHeartbeatCannotRecaptureIt() {
    var routing = KeyboardRouting()
    let snapshot = state()
    routing.update(snapshot, now: 0)
    #expect(routing.route(key: 0, modifiers: [], text: "a", repeating: false, now: 1) == .cancelAndPass)
    routing.update(snapshot, now: 1.1)
    #expect(routing.route(key: 46, modifiers: [], text: "m", repeating: false, now: 1.2) == .pass)
}
@Test func selectionReleasesImmediatelyBeforeUIProcessesQueuedKeystrokes() {
    var routing = KeyboardRouting()
    let snapshot = state()
    routing.update(snapshot, now: 0)
    #expect(routing.route(key: 0, modifiers: [], text: "a", repeating: false, now: 0.1) == .handle(consume: true, generation: snapshot.generation))
    #expect(routing.route(key: 46, modifiers: [], text: "m", repeating: false, now: 0.2) == .handle(consume: true, generation: snapshot.generation))
    routing.update(snapshot, now: 0.3)
    #expect(routing.route(key: 0, modifiers: [], text: "a", repeating: false, now: 0.4) == .pass)
}
@Test func escapeAndPassiveMouseDismissalReleaseImmediately() {
    var routing = KeyboardRouting()
    let snapshot = state()
    routing.update(snapshot, now: 0)
    #expect(routing.route(key: 53, modifiers: [], text: "", repeating: false, now: 0.1) == .handle(consume: true, generation: snapshot.generation))
    #expect(routing.route(key: 0, modifiers: [], text: "a", repeating: false, now: 0.2) == .pass)
    routing.update(state(), now: 0.3)
    routing.disarm()
    #expect(routing.route(key: 0, modifiers: [], text: "a", repeating: false, now: 0.4) == .pass)
}
@Test func screenshotsRecordingAndShortcutsPassThroughWithoutCapturingTyping() {
    var routing = KeyboardRouting()
    routing.update(state(recording: true), now: 0)
    #expect(routing.route(key: 49, modifiers: ["control", "shift"], text: " ", repeating: false, now: 0.1) == .pass)
    let snapshot = state()
    routing.update(snapshot, now: 0.2)
    #expect(routing.route(key: 20, modifiers: ["command", "shift"], text: "3", repeating: false, now: 0.3) == .pass)
    #expect(routing.route(key: 8, modifiers: ["command"], text: "c", repeating: false, now: 0.4) == .handle(consume: false, generation: snapshot.generation))
    #expect(routing.route(key: 0, modifiers: [], text: "a", repeating: false, now: 0.5) == .pass)
}
@Test func pendingDiscoveryNeverConsumesOrdinaryTyping() {
    var routing = KeyboardRouting()
    let snapshot = state(active: false, pending: true)
    routing.update(snapshot, now: 0)
    #expect(routing.route(key: 0, modifiers: [], text: "a", repeating: false, now: 0.1) == .handle(consume: false, generation: snapshot.generation))
}

@Test func cancellingHotkeyDoesNotEatTheTypingThatImmediatelyFollowsIt() {
    var routing = KeyboardRouting()
    routing.update(state(), now: 0)
    #expect(routing.route(key: 49, modifiers: ["control", "shift"], text: " ", repeating: false, now: 0.1) == .handle(consume: true, generation: nil))
    #expect(routing.route(key: 0, modifiers: [], text: "a", repeating: false, now: 0.2) == .pass)
}

@Test func numberedPopupCodesReleaseAfterTheDigitAndBackspaceEditsThePrefix() {
    var routing = KeyboardRouting()
    var snapshot = state()
    snapshot.labels = ["a1", "a2"]
    routing.update(snapshot, now: 0)
    _ = routing.route(key: 0, modifiers: ["shift"], text: "A", repeating: false, now: 0.1)
    _ = routing.route(key: 51, modifiers: [], text: "", repeating: false, now: 0.2)
    _ = routing.route(key: 0, modifiers: [], text: "a", repeating: false, now: 0.3)
    #expect(routing.route(key: 18, modifiers: [], text: "1", repeating: false, now: 0.4) == .handle(consume: true, generation: snapshot.generation))
    #expect(routing.route(key: 0, modifiers: [], text: "a", repeating: false, now: 0.5) == .pass)
}
@Test func inactiveAndDisabledSessionsLeaveNormalKeysAndMouseDismissalAlone() {
    var routing = KeyboardRouting()
    routing.update(state(active: false), now: 0)
    let dismissed = routing.disarm()
    #expect(!dismissed)
    #expect(routing.route(key: 0, modifiers: [], text: "a", repeating: false, now: 0.1) == .pass)
    var snapshot = state(); snapshot.enabled = false
    routing.update(snapshot, now: 0.2)
    #expect(routing.route(key: 49, modifiers: ["control", "shift"], text: " ", repeating: false, now: 0.3) == .pass)
}
