import Foundation
import Testing
@testable import OpenSesameCore

private func place(_ name: String, pinned: Bool = false, time: Double = 0) -> NavigationPlace {
    NavigationPlace(window: StackWindow(bundleID: "test.app", title: name), appName: "Test", regionName: name,
                    region: nil, pinned: pinned, lastVisited: Date(timeIntervalSince1970: time))
}
@Test func explicitSavesKeepTheirSlotsAndRecallNeverAddsPlaces() throws {
    let first = place("First"), second = place("Second")
    var stacks = NavigationStacks()
    try stacks.save(first); try stacks.save(second)
    stacks.visit(UUID())
    #expect(stacks.ordered.map(\.id) == [first.id, second.id])
    #expect(stacks.places.allSatisfy { $0.pinned })
    var updated = first; updated.regionName = "New section"
    try stacks.save(updated)
    #expect(stacks.ordered.map(\.id) == [first.id, second.id])
    #expect(stacks.ordered[0].regionName == "New section")
    stacks.visit(second.id)
    #expect(stacks.last?.id == second.id)
    #expect(stacks.previous()?.id == first.id)
}
@Test func sixthSaveRequiresRemovalAndDoesNotEvictAnyExistingPlace() throws {
    var stacks = NavigationStacks()
    let entries = (0..<6).map { place("Place \($0)", time: Double($0)) }
    for entry in entries.prefix(5) { try stacks.save(entry) }
    let before = stacks.ordered
    #expect(throws: (any Error).self) { try stacks.save(entries[5]) }
    #expect(stacks.ordered == before)
    stacks.remove(entries[1].id)
    try stacks.save(entries[5])
    #expect(stacks.ordered.map(\.id) == [entries[0], entries[2], entries[3], entries[4], entries[5]].map(\.id))
}

@Test func savingConfirmedDuplicatesKeepsTheEarliestSlotAndUnrelatedPlaces() throws {
    let entries = (0..<5).map { place("Place \($0)") }
    var stacks = NavigationStacks(places: entries)
    // Loading never deletes older saves, even if they look alike.
    #expect(stacks.ordered == entries)
    var current = entries[3]; current.regionName = "Updated playback"
    let savedID = try stacks.save(current, replacing: [entries[3].id, entries[1].id])
    #expect(savedID == entries[1].id)
    #expect(stacks.ordered.map(\.id) == [entries[0], entries[1], entries[2], entries[4]].map(\.id))
    #expect(stacks.ordered[1].regionName == current.regionName)
    #expect(stacks.last?.id == entries[1].id)
    #expect(StackPickerState(entries: stacks.ordered).codes == ["1", "2", "3", "4"])
    try stacks.save(stacks.ordered[1])
    #expect(stacks.places.count == 4)
}

@Test func savingAfterRemovingADuplicateReturnsTheSurvivingSlotIdentity() throws {
    let first = place("Playback"), second = place("Playback")
    var stacks = NavigationStacks(places: [first, second])
    stacks.remove(first.id)
    let savedID = try stacks.save(first, replacing: [first.id, second.id])
    #expect(savedID == second.id)
    #expect(stacks.ordered.map(\.id) == [second.id])
}

@Test func resavingAtCapacityUpdatesTheDestinationWithoutEvictingAnother() throws {
    let entries = (0..<5).map { place("Place \($0)") }
    var stacks = NavigationStacks(places: entries)
    var current = place("Fresh snapshot"); current.window = entries[2].window
    try stacks.save(current, replacing: [entries[2].id])
    #expect(stacks.ordered.map(\.id) == entries.map(\.id))
    #expect(stacks.ordered[2].regionName == "Fresh snapshot")
    let before = stacks.ordered
    #expect(throws: (any Error).self) { try stacks.save(place("Sixth"), replacing: [UUID()]) }
    #expect(stacks.ordered == before)
}

@Test func savedPaneBoundsIdentifyChangingContentButKeepNestedPanesDistinct() {
    let anchors = [StackAnchor(role: "AXButton", name: "Play", x: 0.5, y: 0.9)]
    let bounds = StackRegionBounds(x: 0.3, y: 0.7, width: 0.7, height: 0.3)
    let saved = StackRegion(anchors: anchors, bounds: bounds)
    let changed = StackRegion(anchors: [.init(role: "AXButton", name: "Pause", x: 0.5, y: 0.9)], bounds: bounds)
    #expect(saved.sameSavedRegion(as: changed, sameName: true))
    // Similar contents in a nested pane do not make it the same saved place.
    let nested = StackRegion(anchors: anchors, bounds: .init(x: 0.3, y: 0.85, width: 0.7, height: 0.15))
    #expect(!saved.sameSavedRegion(as: nested, sameName: true))
    #expect(saved.similarity(to: changed) == nil) // Recall still needs semantic confidence.
}

@Test func legacyPaneSaveRequiresStableControlsAtTheSamePositionsWhenContentChanges() {
    let stable = (0..<3).map { StackAnchor(role: "AXButton", name: "Playback \($0)", x: 0.3 + Double($0) * 0.1, y: 0.9) }
    let dynamic = (0..<8).map { StackAnchor(role: "AXButton", name: "Track \($0)", x: 0.5, y: 0.8) }
    let old = StackRegion(anchors: stable + dynamic)
    let changed = StackRegion(anchors: stable + [.init(role: "AXButton", name: "New track", x: 0.5, y: 0.8)])
    #expect(old.sameSavedRegion(as: changed, sameName: true))
    #expect(!old.sameSavedRegion(as: changed, sameName: false))
    let moved = StackRegion(anchors: stable.map { .init(role: $0.role, name: $0.name, x: $0.x, y: $0.y - 0.1) })
    #expect(!old.sameSavedRegion(as: moved, sameName: true))
    #expect(!old.sameSavedRegion(as: .init(anchors: Array(stable.prefix(2))), sameName: true))
}
@Test func fiveNumericPickerSlotsRenumberImmediatelyAfterRemoval() {
    let entries = (0..<8).map { place("Window \($0)") }
    var picker = StackPickerState(entries: entries)
    #expect(picker.codes == ["1", "2", "3", "4", "5"])
    picker.move(1)
    picker.remove(entries[1].id)
    #expect(picker.codes == ["1", "2", "3", "4"])
    #expect(picker.selected == entries[2].id)
}
@Test func deletingTheFirstTwoOfThreeStacksMakesTheLastStackNumberOne() {
    let entries = (1...3).map { place("Window \($0)") }
    var picker = StackPickerState(entries: entries)
    picker.remove(entries[0].id); picker.remove(entries[1].id)
    #expect(picker.codes == ["1"])
    #expect(picker.entries.map(\.id) == [entries[2].id])
}
@Test func persistedWindowMatchingRejectsClosedAmbiguousAndUntitledWindows() {
    let window = StackWindow(bundleID: "editor", title: "Project")
    #expect(window.uniqueMatch(in: []) == nil)
    #expect(window.uniqueMatch(in: [window]) == 0)
    #expect(window.uniqueMatch(in: [window, window]) == nil)
    #expect(window.uniqueMatch(in: [.init(bundleID: "other", title: "Project")]) == nil)
    #expect(StackWindow(bundleID: "editor", title: "").uniqueMatch(in: [.init(bundleID: "editor", title: "")]) == nil)
    let stable = StackWindow(bundleID: "editor", title: "Old title", identifier: "document-42")
    #expect(stable.uniqueMatch(in: [.init(bundleID: "editor", title: "New title", identifier: "document-42")]) == 0)
    #expect(stable.uniqueMatch(in: [window]) == nil)
}
@Test func regionAnchorsTolerateAnActionStateChangeButRejectUnrelatedOrBroadScopes() {
    let actions = ["Previous", "Play", "Next", "Repeat"]
    func region(_ names: [String]) -> StackRegion {
        StackRegion(anchors: names.enumerated().map { .init(role: "AXButton", name: $0.element, x: Double($0.offset) * 0.05, y: 0.9) })
    }
    let saved = region(actions)
    #expect(saved.similarity(to: region(["Previous", "Pause", "Next", "Repeat"])) == 0.75)
    #expect(saved.similarity(to: region(["Delete", "Copy", "Paste", "Save"])) == nil)
    #expect(saved.similarity(to: region(actions + ["A", "B", "C", "D", "E", "F"])) == nil)
    #expect(StackRegion(anchors: []).similarity(to: saved) == nil)
    let duplicate = StackRegion(anchors: Array(repeating: .init(role: "AXButton", name: "Play", x: 0.5, y: 0.5), count: 3))
    #expect(duplicate.similarity(to: StackRegion(anchors: [.init(role: "AXButton", name: "Play", x: 0.5, y: 0.5)])) == nil)
}

@Test func regionMatchingAndDeduplicationRejectAmbiguityRegardlessOfOrdering() {
    let anchors = (0..<13).map { StackAnchor(role: "AXButton", name: "Action \($0)", x: Double($0) * 0.01, y: 0.9) }
    let original = StackRegion(anchors: anchors)
    let otherNames = (0..<4).map { StackAnchor(role: "AXButton", name: "New \($0)", x: 0.1, y: 0.9) }
    let changed = StackRegion(anchors: Array(anchors.prefix(8)) + otherNames)
    #expect(original.similarity(to: changed) == 8.0 / 13)
    #expect(original.uniqueMatch(in: [changed]) == 0)
    #expect(original.uniqueMatch(in: [changed, changed]) == nil)
    #expect(original.uniqueMatch(in: [changed, original]) == 1)
    #expect(original.uniqueMatch(in: [original, changed]) == 0)
}
