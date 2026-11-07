import CoreGraphics
import Testing
@testable import OpenSesameCore

@Test func tabCodesStayInsideTabsAndOverflowWhenTheConfiguredGlyphsDoNotFit() throws {
    let bounds = CGRect(x: 0, y: 0, width: 1000, height: 600)
    let tab = CGRect(x: 140, y: 90, width: 240, height: 28)
    let marker = try #require(BadgeLayout.insideTab(control: tab, badge: CGSize(width: 44, height: 26), textHeight: 20,
        bounds: bounds, occupied: []))
    #expect(tab.contains(marker))
    #expect(marker.midY == tab.midY)
    #expect(BadgeLayout.insideTab(control: tab, badge: CGSize(width: 44, height: 34), textHeight: 29, bounds: bounds, occupied: []) == nil)
    #expect(BadgeLayout.insideTab(control: CGRect(x: 140, y: 90, width: 30, height: 28), badge: CGSize(width: 44, height: 26),
        textHeight: 20, bounds: bounds, occupied: []) == nil)
}

@Test func crowdedBadgesKeepReadableSeparation() {
    let bounds = CGRect(x: 0, y: 0, width: 400, height: 200)
    let first = CGRect(x: 20, y: 100, width: 35, height: 24)
    let touching = first.offsetBy(dx: 36, dy: 0)
    let clear = first.offsetBy(dx: 0, dy: -32)
    #expect(BadgeLayout.place(candidates: [touching, clear], bounds: bounds, occupied: [first], controls: []) == clear)
    #expect(BadgeLayout.place(candidates: [first], bounds: bounds, occupied: [first], controls: []) == nil)
}

@Test func inlineTabHintsUseTheGapBetweenATitleAndItsCloseButton() throws {
    let bounds = CGRect(x: 0, y: 0, width: 500, height: 200)
    let tab = CGRect(x: 100, y: 80, width: 240, height: 32)
    let title = CGRect(x: 112, y: 88, width: 132, height: 16)
    let close = CGRect(x: 312, y: 86, width: 20, height: 20)
    let marker = try #require(BadgeLayout.insideTab(control: tab, badge: CGSize(width: 44, height: 26),
        textHeight: 20, bounds: bounds, occupied: [title, close]))
    #expect(tab.contains(marker))
    #expect(marker.minX > title.maxX)
    #expect(marker.maxX < close.minX)
    #expect(BadgeLayout.insideTab(control: tab, badge: CGSize(width: 44, height: 26), textHeight: 20,
        bounds: bounds, occupied: [tab]) == nil)
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
