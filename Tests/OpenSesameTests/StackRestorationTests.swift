import AppKit
import ApplicationServices
import Foundation
import Testing
import OpenSesameCore
@testable import OpenSesame

@Test func desktopOpenTakesPriorityOverItsContextMenu() {
    #expect(Discovery.primaryAction(in: ["AXShowMenu", "AXOpen"]) == "AXOpen")
    #expect(Discovery.primaryAction(in: ["AXShowMenu", "AXPress", "AXOpen"]) == "AXPress")
    #expect(Discovery.primaryAction(in: ["AXShowMenu"]) == "AXShowMenu")
    #expect(Discovery.primaryAction(in: ["AXRaise"]) == nil)
}

private func controls(in window: CGRect, title: String = "Action") -> [Target] {
    (0..<90).map { index in
        Target(element: AXUIElementCreateApplication(0),
               frame: CGRect(x: window.minX + CGFloat(index % 10) * window.width / 10,
                             y: window.minY + CGFloat(index / 10) * window.height / 10, width: 24, height: 24),
               label: "old\(index)", kind: .control, action: "AXPress", clicksMenuBarExtra: false,
               metadata: TargetMetadata(role: "AXButton", subrole: "", title: "\(title) \(index)", description: "", owner: 0, bundleID: "test"))
    }
}
@Test func freshRestorationSurvivesMovingWindowsAndChangingAlphabetsAndKeepsParents() throws {
    let oldWindow = CGRect(x: 40, y: 80, width: 600, height: 600)
    let newWindow = CGRect(x: 1400, y: 400, width: 720, height: 720)
    var original = SectionNavigation()
    _ = original.reset(controls(in: oldWindow), scopedPopup: false, configuration: .standard)
    while original.sectionCount > 0 { #expect(original.select(original.targets.last!.label, configuration: .standard) == true) }
    let anchor = original.anchor(in: oldWindow)
    let config = try HintConfiguration(minimumLength: 3, alphabet: "jk", prefix: "go")
    var fresh = SectionNavigation()
    _ = fresh.reset(controls(in: newWindow), scopedPopup: false, configuration: config)
    #expect(fresh.restore(anchor, window: newWindow, configuration: config) == true)
    #expect(fresh.regionTargets.map(\.metadata.title) == original.regionTargets.map(\.metadata.title))
    #expect(fresh.targets.allSatisfy { $0.label.hasPrefix("go") })
    #expect(fresh.targets.allSatisfy { newWindow.contains($0.frame) })
    #expect(fresh.back() == true)
    #expect(fresh.sectionCount > 0)
}
@Test func changedRegionsFallBackToFreshWindowChoices() {
    let window = CGRect(x: 0, y: 0, width: 600, height: 600)
    var old = SectionNavigation()
    _ = old.reset(controls(in: window), scopedPopup: false, configuration: .standard)
    #expect(old.select(old.targets[0].label, configuration: .standard) == true)
    var fresh = SectionNavigation()
    let root = fresh.reset(controls(in: window, title: "Other"), scopedPopup: false, configuration: .standard)
    #expect(fresh.restore(old.anchor(in: window), window: window, configuration: .standard) == false)
    #expect(fresh.depth == 0 && fresh.targets.map(\.label) == root.map(\.label))
}

@Test func recallKeepsTheLeafWhenDynamicContentChangesAroundEightStableControls() {
    let window = CGRect(x: 0, y: 0, width: 1800, height: 700)
    func fixture(changed: Bool) -> [Target] {
        (0..<78).compactMap { index -> Target? in
            let cluster = index / 13, item = index % 13
            if changed && cluster == 4 && item == 12 { return nil }
            let name = changed && cluster == 4 && item >= 8 ? "Changed \(index)" : "Action \(index)"
            let x = CGFloat(40 + (cluster % 3) * 600 + (item % 5) * 30)
            let y = CGFloat(40 + (cluster / 3) * 320 + (item / 5) * 30)
            let frame = CGRect(x: x, y: y, width: 24, height: 24)
            return Target(element: AXUIElementCreateApplication(0),
                frame: frame,
                label: "old\(index)", kind: .control, action: "AXPress", clicksMenuBarExtra: false,
                metadata: TargetMetadata(role: "AXButton", subrole: "", title: name, description: "", owner: 0, bundleID: "test"))
        }
    }
    var saved = SectionNavigation()
    _ = saved.reset(fixture(changed: false), scopedPopup: false, configuration: .standard, windowFrame: window)
    #expect(saved.select(saved.targets[1].label, configuration: .standard) == true)
    #expect(saved.select(saved.targets.last!.label, configuration: .standard) == true)
    #expect(saved.depth == 2 && saved.regionTargets.count == 13)
    let anchor = saved.anchor(in: window)
    var fresh = SectionNavigation()
    _ = fresh.reset(fixture(changed: true), scopedPopup: false, configuration: .standard, windowFrame: window)
    #expect(fresh.restore(anchor, window: window, configuration: .standard) == true)
    #expect(fresh.depth == saved.depth && fresh.sectionCount == 0 && fresh.regionTargets.count == 12)
    #expect(anchor.similarity(to: fresh.anchor(in: window)) == 8.0 / 13)
    #expect(fresh.regionDescription(in: window) == "Lower center")
    #expect(fresh.back() && fresh.sectionCount == 2)
    #expect(fresh.back() && fresh.depth == 0)
}
@Test func liveWindowReferenceDoesNotSubstituteASameNamedReplacement() {
    let old = AXUIElementCreateApplication(101), replacement = AXUIElementCreateApplication(202)
    let saved = StackWindow(bundleID: "test", title: "Same title")
    let live = StackWindowResolver.LiveWindow(owner: 5, element: old)
    #expect(StackWindowResolver.resolve(saved, live: live, owners: [5], load: { _ in [replacement] }, describe: { _ in saved }) == nil)
    let result = StackWindowResolver.resolve(saved, live: live, owners: [5], load: { _ in [replacement, old] }, describe: { _ in saved })
    #expect(result.map { CFEqual($0.element, old) } == true)
    #expect(StackWindowResolver.resolve(saved, live: nil, owners: [5], load: { _ in [replacement, old] }, describe: { _ in saved }) == nil)
}

@Test func savedWindowDeduplicationResolvesAfterRestartAndRejectsAmbiguousTitles() {
    let window = AXUIElementCreateApplication(101), sibling = AXUIElementCreateApplication(202)
    let identity = StackWindow(bundleID: "test", title: "Music")
    let saved = NavigationPlace(window: identity, appName: "Test", regionName: "Playback", region: nil)
    var other = saved; other.id = UUID(); other.window.bundleID = "other"
    let current = StackWindowResolver.Resolved(owner: 5, element: window)
    let restart = StackWindowResolver.matchingPlaces([saved, other], current: current, live: [:],
        windows: [window], describe: { _ in identity })
    #expect(restart.map(\.id) == [saved.id])
    let ambiguous = StackWindowResolver.matchingPlaces([saved], current: current, live: [:],
        windows: [window, sibling], describe: { _ in identity })
    #expect(ambiguous.isEmpty)
    let known = StackWindowResolver.matchingPlaces([saved], current: current,
        live: [saved.id: .init(owner: 5, element: window)], windows: [window, sibling], describe: { _ in identity })
    #expect(known.map(\.id) == [saved.id])
    let otherLive = StackWindowResolver.matchingPlaces([saved], current: current,
        live: [saved.id: .init(owner: 5, element: sibling)], windows: [window, sibling], describe: { _ in identity })
    #expect(otherLive.isEmpty)
}
