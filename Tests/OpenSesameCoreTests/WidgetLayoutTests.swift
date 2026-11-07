import CoreGraphics
import Testing
@testable import OpenSesameCore

@Test func distantFocusTagFallsBackInsteadOfFloatingBelowThePopup() {
    let popup = CGRect(x: 200, y: 200, width: 320, height: 520)
    let focus = CGRect(x: 380, y: 440, width: 140, height: 64)
    let occupied = [popup.insetBy(dx: -8, dy: -8)]
    #expect(WidgetLayout.exterior(control: focus, surface: popup, badge: CGSize(width: 64, height: 26),
        bounds: CGRect(x: 0, y: 0, width: 600, height: 900), occupied: occupied, obstacles: [popup]) == nil)
    #expect(!WidgetLayout.isAssociated(CGRect(x: 380, y: 100, width: 64, height: 26), with: focus))
}

@Test func transparentPopupHostDoesNotPushLabelsAwayFromVisibleWidgets() {
    let reported = CGRect(x: 4640, y: 0, width: 656, height: 964)
    let tiles = [CGRect(x: 4813, y: 41, width: 141, height: 64), CGRect(x: 4966, y: 41, width: 140, height: 140), CGRect(x: 4913, y: 503, width: 94, height: 24)]
    let surface = WidgetLayout.contentSurface(reported: reported, controls: tiles, text: [])
    #expect(surface.minX == 4801)
    #expect(surface.maxX == 5118)
    #expect(surface.maxY == 539)
    #expect(surface.contains(tiles[0]) && surface.contains(tiles[2]))
}
@Test func ordinaryPopupBoundsStayIntactAndCaptionsMayExtendContent() {
    let popup = CGRect(x: 100, y: 100, width: 300, height: 200)
    let controls = [CGRect(x: 116, y: 116, width: 268, height: 168)]
    #expect(WidgetLayout.contentSurface(reported: popup, controls: controls, text: []) == popup)
}
@Test func twoMediaButtonsUseTheSameBelowRuleAsLongerRows() {
    let controls = (0..<2).map { CompactRowLayout.Control(index: $0, owner: 1, frame: CGRect(x: 100 + $0 * 30, y: 200, width: 30, height: 30)) }
    let layout = CompactRowLayout.arrange(controls: controls, badge: CGSize(width: 40, height: 28), bounds: CGRect(x: 0, y: 0, width: 500, height: 400), surface: nil, obstacles: controls.map(\.frame))
    #expect(layout.count == 2)
    #expect(layout[0]!.frame.minX < controls[0].frame.midX && layout[0]!.frame.maxX > controls[0].frame.midX)
    #expect(layout[1]!.frame.minX < controls[1].frame.midX && layout[1]!.frame.maxX > controls[1].frame.midX)
    #expect(layout[0]?.frame.minY == layout[1]?.frame.minY)
    #expect(layout.values.allSatisfy { $0.frame.maxY < 200 })
}
@Test func denseRowsStayInOneLocalStripWithoutCoveringFollowingMenuItems() {
    let controls = (0..<4).map { CompactRowLayout.Control(index: $0, owner: 1, frame: CGRect(x: 100 + $0 * 32, y: 200, width: 24, height: 24)) }
    let settings = CGRect(x: 100, y: 175, width: 180, height: 18)
    let layout = CompactRowLayout.arrange(controls: controls, badge: CGSize(width: 40, height: 28), bounds: CGRect(x: 0, y: 0, width: 500, height: 400), surface: CGRect(x: 90, y: 120, width: 200, height: 180), obstacles: controls.map(\.frame) + [settings], captionHeight: 14)
    #expect(layout.count == 4)
    for placement in layout.values {
        #expect(!placement.outsideSurface)
        #expect(placement.reservation == placement.frame)
        #expect(!placement.reservation.intersects(settings))
    }
    for left in layout.keys {
        for right in layout.keys where left < right { #expect(!layout[left]!.reservation.intersects(layout[right]!.reservation)) }
    }
}
@Test func widgetUsesClearAboveGutterWhenBelowContainsText() throws {
    let tile = CGRect(x: 100, y: 200, width: 140, height: 64)
    let following = CGRect(x: 100, y: 165, width: 140, height: 25)
    let title = CGRect(x: 115, y: 240, width: 100, height: 15)
    let result = WidgetLayout.nearby(control: tile, badge: CGSize(width: 40, height: 28), bounds: CGRect(x: 0, y: 0, width: 500, height: 400), occupied: [], controls: [tile], text: [following, title])
    let badge = try #require(result)
    #expect(badge.minY > tile.maxY)
    #expect(!badge.intersects(title))
}

@Test func widgetNeverCoversItsOwnIconWhenBothGuttersAreBlocked() {
    let tile = CGRect(x: 100, y: 200, width: 140, height: 64)
    let text = [CGRect(x: 40, y: 160, width: 200, height: 35), CGRect(x: 40, y: 270, width: 200, height: 30), CGRect(x: 40, y: 200, width: 55, height: 64)]
    #expect(WidgetLayout.nearby(control: tile, badge: CGSize(width: 40, height: 28), bounds: CGRect(x: 0, y: 0, width: 500, height: 400), occupied: [], controls: [tile], text: text) == nil)
    let exterior = WidgetLayout.exterior(control: tile, surface: CGRect(x: 90, y: 150, width: 200, height: 160), badge: CGSize(width: 40, height: 28), bounds: CGRect(x: 0, y: 0, width: 500, height: 400), occupied: [], obstacles: [tile] + text)
    #expect(exterior == nil) // Shared overflow is preferable to a detached tag.
}

@Test func captionOverflowFallsBackWhenOnlyDistantColumnsRemain() {
    let popup = CGRect(x: 200, y: 80, width: 140, height: 180)
    let bounds = CGRect(x: 0, y: 0, width: 600, height: 340)
    // Occupy every local column above/below this narrow popup.
    let occupied = [CGRect(x: 195, y: 0, width: 150, height: 80), CGRect(x: 195, y: 260, width: 150, height: 80)]
    #expect(WidgetLayout.exterior(control: popup, surface: popup, badge: CGSize(width: 100, height: 28),
        bounds: bounds, occupied: occupied, obstacles: [popup], captionHeight: 22) == nil)
}

@Test func individualHintsPreferUpperLeftWithoutCoveringTheirTarget() throws {
    let control = CGRect(x: 200, y: 200, width: 30, height: 24)
    let frame = try #require(WidgetLayout.nearby(control: control, badge: CGSize(width: 40, height: 30),
        bounds: CGRect(x: 0, y: 0, width: 500, height: 400), occupied: [], controls: [control], text: []))
    #expect(frame.minX < control.minX)
    #expect(frame.minY == control.maxY + WidgetLayout.gap)
    #expect(!frame.intersects(control))
}

@Test func verticalToolbarUsesLeftGutterWhenAdjacentButtonsBlockAboveAndBelow() throws {
    let controls = (0..<5).map { CGRect(x: 440, y: 100 + $0 * 32, width: 28, height: 28) }
    let frame = try #require(WidgetLayout.nearby(control: controls[2], badge: CGSize(width: 40, height: 30),
        bounds: CGRect(x: 0, y: 0, width: 500, height: 400), occupied: [], controls: controls, text: []))
    #expect(frame.maxX < controls[2].minX)
    #expect(!controls.contains { $0.intersects(frame) })
}

@Test func upperLeftHintsFallBackInsideOffsetDisplayBounds() throws {
    let bounds = CGRect(x: -500, y: 100, width: 500, height: 400)
    let control = CGRect(x: -496, y: 200, width: 60, height: 24)
    let frame = try #require(WidgetLayout.nearby(control: control, badge: CGSize(width: 40, height: 30),
        bounds: bounds, occupied: [], controls: [control], text: []))
    #expect(bounds.insetBy(dx: 4, dy: 4).contains(frame))
    #expect(frame.minY > control.maxY)
}

@Test func verticalToolbarKeepsEndButtonsInTheSameLeftLanesAtLargeSize() throws {
    let controls = (0..<5).map { CGRect(x: 440, y: 100 + $0 * 36, width: 28, height: 28) }
    var occupied: [CGRect] = []
    for control in controls {
        let frame = try #require(WidgetLayout.nearby(control: control, badge: CGSize(width: 52, height: 33),
            bounds: CGRect(x: 0, y: 0, width: 500, height: 400), occupied: occupied, controls: controls, text: []))
        #expect(frame.midY == control.midY)
        #expect(frame.maxX < control.minX)
        #expect(!occupied.contains { $0.insetBy(dx: -5, dy: -5).intersects(frame) })
        occupied.append(frame)
    }
    #expect(Set(occupied.map(\.minX)).count == 2)
}
