import CoreGraphics
import Testing
@testable import OpenSesameCore

@Test func crowdedBadgesKeepReadableSeparation() {
    let bounds = CGRect(x: 0, y: 0, width: 400, height: 200)
    let first = CGRect(x: 20, y: 100, width: 35, height: 24)
    let touching = first.offsetBy(dx: 36, dy: 0)
    let clear = first.offsetBy(dx: 0, dy: -32)
    #expect(BadgeLayout.place(candidates: [touching, clear], bounds: bounds, occupied: [first], controls: []) == clear)
    #expect(BadgeLayout.place(candidates: [first], bounds: bounds, occupied: [first], controls: []) == nil)
}
@Test func placementPrefersUncoveredControlsAndStaysOnScreen() {
    let bounds = CGRect(x: 0, y: 0, width: 400, height: 200)
    let control = CGRect(x: 20, y: 100, width: 35, height: 24)
    let outside = control.offsetBy(dx: -100, dy: 0)
    let clear = control.offsetBy(dx: 0, dy: -32)
    #expect(BadgeLayout.place(candidates: [outside, control, clear], bounds: bounds, occupied: [], controls: [control]) == clear)
    #expect(BadgeLayout.place(candidates: [outside], bounds: bounds, occupied: [], controls: []) == nil)
}

@Test func placementDoesNotPreferDistantSpaceOverNearbyLabels() {
    let bounds = CGRect(x: 0, y: 0, width: 400, height: 400)
    let nearby = CGRect(x: 20, y: 100, width: 35, height: 24)
    let closeCandidates = (0..<4).map { nearby.offsetBy(dx: CGFloat($0), dy: 0) }
    let distant = nearby.offsetBy(dx: 0, dy: 200)
    let coveringControl = CGRect(x: 0, y: 80, width: 100, height: 70)
    #expect(BadgeLayout.place(candidates: closeCandidates + [distant], bounds: bounds, occupied: [], controls: [coveringControl]) == nearby)
}

@Test func ordinaryHintsStayHorizontalAndFlipAtScreenEdge() {
    let control = CGRect(x: 350, y: 100, width: 40, height: 24)
    let candidates = BadgeLayout.candidates(control: control, badge: CGSize(width: 40, height: 24), menuBar: false, index: 0)
    #expect(candidates.allSatisfy { $0.midY == control.midY })
    let placed = BadgeLayout.place(candidates: candidates, bounds: CGRect(x: 0, y: 0, width: 400, height: 200), occupied: [], controls: [control])
    #expect(placed != nil)
    #expect(placed!.maxX < control.minX)
    let staggered = BadgeLayout.candidates(control: control, badge: CGSize(width: 40, height: 24), menuBar: false, index: 1)
    #expect(staggered[0].minX > candidates[0].minX)
}
@Test func menuBarHintsStayVertical() {
    let control = CGRect(x: 150, y: 175, width: 30, height: 24)
    let candidates = BadgeLayout.candidates(control: control, badge: CGSize(width: 40, height: 24), menuBar: true, index: 1)
    #expect(candidates.allSatisfy { $0.midX == control.midX && $0.maxY < control.minY })
}

@Test func badgesPreferTheSideFacingScreenCenter() {
    let bounds = CGRect(x: 0, y: 0, width: 1000, height: 600)
    for x: CGFloat in [100, 800] {
        let control = CGRect(x: x, y: 200, width: 40, height: 24)
        let candidates = BadgeLayout.candidates(control: control, badge: CGSize(width: 40, height: 24), menuBar: false, index: 0, bounds: bounds)
        #expect(x < bounds.midX ? candidates[0].minX > control.maxX : candidates[0].maxX < control.minX)
    }
}

@Test func denseMenuRowsKeepTwoRepeatingLanes() {
    let bounds = CGRect(x: 0, y: 0, width: 1000, height: 600)
    var occupied: [CGRect] = []
    var positions: [CGFloat] = []
    for index in 0..<8 {
        let control = CGRect(x: 800, y: 400 - index * 24, width: 190, height: 24)
        let candidates = BadgeLayout.candidates(control: control, badge: CGSize(width: 40, height: 30), menuBar: false, index: index, bounds: bounds)
        let placed = BadgeLayout.place(candidates: candidates, bounds: bounds, occupied: occupied, controls: [control])
        #expect(placed == candidates[0])
        if let placed { occupied.append(placed); positions.append(placed.minX) }
    }
    #expect(Set(positions).count == 2)
    #expect(positions[0] == positions[2] && positions[1] == positions[3])
}

@Test func fullWidthWindowsKeepHintsAtOneInsideEdge() {
    let bounds = CGRect(x: 0, y: 0, width: 1440, height: 900)
    var occupied: [CGRect] = []
    for index in 0..<6 {
        let row = CGRect(x: 0, y: 400 - index * 24, width: 1440, height: 24)
        let candidates = BadgeLayout.candidates(control: row, badge: CGSize(width: 40, height: 32), menuBar: false, index: index, bounds: bounds)
        let placed = BadgeLayout.place(candidates: candidates, bounds: bounds, occupied: occupied, controls: [row])
        #expect(placed != nil)
        if let placed { #expect(bounds.contains(placed)); occupied.append(placed) }
    }
}

@Test func inlineTabBadgesStayInsideTheTabNearItsLeftEdge() {
    let tab = CGRect(x: 220, y: 300, width: 360, height: 24)
    let badge = BadgeLayout.inlineTab(control: tab, badge: CGSize(width: 40, height: 30))
    #expect(badge != nil)
    #expect(tab.contains(badge!))
    #expect(badge!.minX == tab.minX + 8)
    #expect(badge!.midY == tab.midY)
    // A narrow new-tab button cannot contain an unclipped two-letter code.
    #expect(BadgeLayout.inlineTab(control: CGRect(x: 0, y: 0, width: 30, height: 30), badge: CGSize(width: 40, height: 30)) == nil)
}

@Test func overlappingWindowSelectorsGetSeparateTitleBarPositions() {
    let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let window = CGRect(x: 100, y: 100, width: 600, height: 500)
    var occupied: [CGRect] = []
    for offset: CGFloat in [0, 0, 20] {
        let frame = window.offsetBy(dx: offset, dy: 0)
        let candidates = BadgeLayout.windowTitle(control: frame, badge: CGSize(width: 40, height: 30))
        let placed = BadgeLayout.place(candidates: candidates, bounds: bounds, occupied: occupied, controls: [])
        #expect(placed != nil)
        if let placed { #expect(frame.contains(placed)); occupied.append(placed) }
    }
    #expect(Set(occupied.map { $0.minX }).count == 3)
}

@Test func goldWindowSelectorDoesNotHideAnInlineTabHint() {
    let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let window = CGRect(x: 100, y: 100, width: 600, height: 500)
    let tab = CGRect(x: 400, y: 576, width: 300, height: 24)
    let size = CGSize(width: 40, height: 30)
    let gold = BadgeLayout.place(candidates: BadgeLayout.windowTitle(control: window, badge: size), bounds: bounds, occupied: [], controls: [])!
    let inline = BadgeLayout.place(candidates: BadgeLayout.inlineTabCandidates(control: tab, badge: size), bounds: bounds, occupied: [gold], controls: [])
    #expect(inline != nil)
    #expect(tab.contains(inline!))
    #expect(!gold.insetBy(dx: -5, dy: -5).intersects(inline!))
}
