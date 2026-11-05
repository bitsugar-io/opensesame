import Testing
@testable import OpenSesameCore

@Test func cancellationRevokesQueuedActionsAndScanResults() {
    var life = HintLifecycle()
    let action = life.generation
    let followup = life.beginFollowup()
    life.cancel()
    #expect(!life.accepts(generation: action))
    #expect(!life.accepts(generation: action, followup: followup))
    #expect(!life.followingAction)
}
@Test func appHandoffPreservesFollowupButRejectsOldScan() {
    var life = HintLifecycle()
    let followup = life.beginFollowup()
    let oldScan = life.generation
    life.cancel(preservingFollowup: true)
    #expect(!life.accepts(generation: oldScan, followup: followup))
    #expect(life.accepts(generation: life.generation, followup: followup))
    // An empty early scan does not finish the follow-up. A later retry remains valid.
    life.cancel(preservingFollowup: true)
    #expect(life.accepts(generation: life.generation, followup: followup))
}
@Test func expiredFollowupCannotPublishEvenWithCurrentScanGeneration() {
    var life = HintLifecycle()
    let followup = life.beginFollowup()
    let scan = life.generation
    life.finishFollowup(followup)
    #expect(!life.accepts(generation: scan, followup: followup))
    #expect(life.accepts(generation: scan))
}
@Test func oldCompletionCannotFinishANewerAction() {
    var life = HintLifecycle()
    let old = life.beginFollowup()
    let new = life.beginFollowup()
    life.finishFollowup(old)
    #expect(life.followingAction)
    #expect(life.accepts(generation: life.generation, followup: new))
    #expect(!life.accepts(generation: life.generation, followup: old))
}
