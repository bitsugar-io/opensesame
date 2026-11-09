import Foundation
import Testing
@testable import OpenSesameCore

private func state(_ generation: UUID = UUID(), active: Bool = true, pending: Bool = false, recording: Bool = false) -> KeyboardRouting.Snapshot {
    .init(generation: generation, shortcut: Shortcut(), enabled: true, recording: recording, active: active, pending: pending, labels: ["am", "av"])
}
@Test func saveStackShortcutOnlyCapturesDuringHintsAndReleasesWhileSaving() {
    var routing = KeyboardRouting()
    let binding = Shortcut(keyCode: 1, modifiers: ["command", "option"], key: "S")
    var idle = state(active: false); idle.saveStackShortcut = binding
    routing.update(idle, now: 0)
    #expect(routing.route(key: 1, modifiers: ["command", "option"], text: "s", repeating: false, now: 0.1) == .pass)
    var hints = state(); hints.saveStackShortcut = binding
    routing.update(hints, now: 0.2)
    #expect(routing.route(key: 1, modifiers: ["command", "option"], text: "s", repeating: false, now: 0.3) == .handle(consume: true, generation: hints.generation))
    #expect(routing.route(key: 1, modifiers: ["command", "option"], text: "s", repeating: true, now: 0.4) == .pass)
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

@Test func configurableStacksShortcutWorksGloballyAndCommandsReleaseBeforeRecall() {
    var routing = KeyboardRouting()
    var snapshot = state(active: false)
    snapshot.stacksShortcut = Shortcut(keyCode: 40, modifiers: ["option", "command"], key: "K")
    routing.update(snapshot, now: 0)
    #expect(routing.route(key: 49, modifiers: ["control", "option"], text: "", repeating: false, now: 0.1) == .pass)
    #expect(routing.route(key: 40, modifiers: ["command", "option"], text: "", repeating: false, now: 0.2) == .handle(consume: true, generation: nil))
    for (key, modifiers) in [(49, Set<String>()), (36, []), (51, ["shift"])] {
        let active = state()
        routing.update(active, now: 1)
        #expect(routing.route(key: key, modifiers: modifiers, text: "", repeating: false, now: 1.1) == .handle(consume: true, generation: active.generation))
        #expect(routing.route(key: 0, modifiers: [], text: "a", repeating: false, now: 1.2) == .pass)
    }
}
@Test func pickerArrowCommandsPreserveCodesAndMouseOnlyDismissesOutside() {
    var routing = KeyboardRouting()
    var picker = state(); picker.stacksOpen = true
    picker.mousePassthroughFrame = CGRect(x: 100, y: 100, width: 600, height: 500)
    routing.update(picker, now: 0)
    for key in [125, 126, 48] {
        #expect(routing.route(key: key, modifiers: [], text: "", repeating: false, now: 0.1) == .handle(consume: true, generation: picker.generation))
    }
    #expect(routing.mouse(at: CGPoint(x: 200, y: 200)) == false)
    #expect(routing.route(key: 0, modifiers: [], text: "a", repeating: false, now: 0.2) == .handle(consume: true, generation: picker.generation))
    #expect(routing.mouse(at: .zero) == true)
    #expect(routing.route(key: 46, modifiers: [], text: "m", repeating: false, now: 0.3) == .pass)
}
@Test func recallPendingCancellationCannotBeRearmedByALateHeartbeat() {
    var routing = KeyboardRouting()
    let pending = state(active: false, pending: true)
    routing.update(pending, now: 0)
    #expect(routing.route(key: 0, modifiers: [], text: "a", repeating: false, now: 0.1) == .handle(consume: false, generation: pending.generation))
    routing.update(pending, now: 0.2)
    #expect(routing.route(key: 46, modifiers: [], text: "m", repeating: false, now: 0.3) == .pass)
}

@Test func stackRemovalAndUndoStayInThePickerAndDigitsRecallInOneKey() {
    var routing = KeyboardRouting()
    var picker = state(); picker.stacksOpen = true; picker.labels = ["1", "2", "3", "4", "5"]
    routing.update(picker, now: 0)
    for key in [51, 6] {
        #expect(routing.route(key: key, modifiers: ["command"], text: "", repeating: false, now: 0.1) == .handle(consume: true, generation: picker.generation))
        #expect(routing.route(key: key, modifiers: ["command"], text: "", repeating: true, now: 0.2) == .consume)
    }
    #expect(routing.route(key: 21, modifiers: [], text: "4", repeating: false, now: 0.3) == .handle(consume: true, generation: picker.generation))
    #expect(routing.route(key: 0, modifiers: [], text: "a", repeating: false, now: 0.4) == .pass)
}
