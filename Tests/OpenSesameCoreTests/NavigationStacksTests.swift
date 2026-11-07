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
