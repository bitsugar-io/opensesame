import ApplicationServices
import Testing
import OpenSesameCore
@testable import OpenSesame

@Test func selectedWindowRefreshRequiresTheExactForegroundWindow() {
    let window = AXUIElementCreateApplication(1), other = AXUIElementCreateApplication(2)
    let selected = StackWindowResolver.Resolved(owner: 42, element: window)
    #expect(WindowSelection.isFocused(selected, frontOwner: 42, read: { _, _ in window }))
    #expect(!WindowSelection.isFocused(selected, frontOwner: 43, read: { _, _ in window }))
    #expect(!WindowSelection.isFocused(selected, frontOwner: 42, read: { _, _ in other }))
    #expect(!WindowSelection.isFocused(selected, frontOwner: 42, read: { _, _ in nil }))
}

@Test func cancellationDiscardsAWindowTransitionAndItsPendingScan() {
    var lifecycle = HintLifecycle()
    let transition = lifecycle.beginFollowup()
    lifecycle.cancel(preservingFollowup: true)
    let scan = lifecycle.generation
    #expect(lifecycle.accepts(generation: scan, followup: transition))
    lifecycle.cancel()
    #expect(!lifecycle.accepts(generation: scan, followup: transition))
    #expect(!lifecycle.followingAction)
}

@Test func windowFocusTransitionRefreshesOnceAndCancellationPreventsLateHints() {
    for cancel in [false, true] {
        var current = true, focused = false, scans = 0, failures = 0
        var probes: [() -> Void] = []
        WindowSelection.waitForFocus(isCurrent: { current }, focused: { focused },
            schedule: { _, probe in probes.append(probe) }, refresh: { scans += 1 }, unavailable: { failures += 1 })
        probes[0]()
        #expect(scans == 0)
        focused = true; current = !cancel
        for probe in probes.dropFirst() { probe() }
        #expect(scans == (cancel ? 0 : 1))
        #expect(failures == 0)
    }
    var probes: [() -> Void] = [], failures = 0
    WindowSelection.waitForFocus(isCurrent: { true }, focused: { false }, schedule: { _, probe in probes.append(probe) },
        refresh: { Issue.record("Do not refresh a window that failed to activate") }, unavailable: { failures += 1 })
    probes.forEach { $0() }
    #expect(failures == 1)
}
