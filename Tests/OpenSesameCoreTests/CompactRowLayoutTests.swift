import CoreGraphics
import Testing
@testable import OpenSesameCore

@Test func durationPresetsStayAlignedWithoutCoveringSettingsBelow() {
    let controls = [16,55,87,119,158,190,222,261].enumerated().map {
        CompactRowLayout.Control(index: $0.offset, owner: 10, frame: CGRect(x: 100 + $0.element, y: 300, width: 24, height: 24))
    }
    let surface = CGRect(x: 100, y: 200, width: 300, height: 209)
    let settings = CGRect(x: 116, y: 266, width: 267, height: 15)
    let layout = CompactRowLayout.arrange(controls: controls, badge: CGSize(width: 40, height: 30),
        bounds: CGRect(x: 0, y: 0, width: 800, height: 600), surface: surface, obstacles: controls.map(\.frame) + [settings])
    #expect(layout.count == 8)
    #expect(Set(layout.values.map { $0.frame.minY }).count == 1)
    for control in controls {
        #expect(layout[control.index]?.outsideSurface == false)
        #expect(!layout[control.index]!.frame.intersects(settings))
        #expect(!controls.contains { $0.frame.intersects(layout[control.index]!.frame) })
    }
}
@Test func compactMediaControlsPreferSmallGapsDirectlyBelow() {
    let controls = (0..<3).map { CompactRowLayout.Control(index: $0, owner: 20, frame: CGRect(x: 100 + $0 * 60, y: 200, width: 24, height: 24)) }
    let layout = CompactRowLayout.arrange(controls: controls, badge: CGSize(width: 40, height: 28),
        bounds: CGRect(x: 0, y: 0, width: 600, height: 400), surface: nil, obstacles: controls.map(\.frame))
    #expect(layout.count == 3)
    #expect(layout.values.allSatisfy { $0.frame.maxY == 194 && !$0.outsideSurface })
}
@Test func compactRowsDoNotCombineDifferentAppsOrOrdinaryMenuRows() {
    let controls = (0..<3).map { CompactRowLayout.Control(index: $0, owner: Int32($0), frame: CGRect(x: 100 + $0 * 40, y: 200, width: 24, height: 24)) }
    #expect(CompactRowLayout.arrange(controls: controls, badge: CGSize(width: 40, height: 28), bounds: CGRect(x: 0, y: 0, width: 600, height: 400), surface: nil, obstacles: []).isEmpty)
}

@Test func compactStripStaysLocalWhenTextFillsTheGutter() {
    let controls = (0..<3).map { CompactRowLayout.Control(index: $0, owner: 1, frame: CGRect(x: 100 + $0 * 40, y: 200, width: 20, height: 20)) }
    let text = CGRect(x: 145, y: 180, width: 10, height: 10)
    let layout = CompactRowLayout.arrange(controls: controls, badge: CGSize(width: 40, height: 28),
        bounds: CGRect(x: 0, y: 0, width: 600, height: 400), surface: nil, obstacles: controls.map(\.frame) + [text])
    #expect(layout.count == 3)
    #expect(layout.values.allSatisfy { $0.frame.minY == 226 && !$0.frame.intersects(text) })
}

@Test func crowdedPopupRowsMoveBelowSurfaceInsteadOfCoveringChoices() {
    let controls = (0..<4).map { CompactRowLayout.Control(index: $0, owner: 1, frame: CGRect(x: 100 + $0 * 32, y: 200, width: 24, height: 24)) }
    let captions = [CGRect(x: 90, y: 170, width: 200, height: 24), CGRect(x: 90, y: 230, width: 200, height: 24)]
    let layout = CompactRowLayout.arrange(controls: controls, badge: CGSize(width: 40, height: 28), bounds: CGRect(x: 0, y: 0, width: 500, height: 400), surface: CGRect(x: 80, y: 164, width: 220, height: 106), obstacles: controls.map(\.frame) + captions, captionHeight: 14)
    #expect(layout.count == 4)
    for placement in layout.values {
        #expect(placement.outsideSurface)
        #expect(placement.frame.maxY < 164)
        #expect(placement.reservation.height == placement.frame.height + 14)
        #expect(!(controls.map(\.frame) + captions).contains { $0.intersects(placement.reservation) })
    }
    let distant = CompactRowLayout.arrange(controls: controls, badge: CGSize(width: 40, height: 28), bounds: CGRect(x: 0, y: 0, width: 500, height: 400), surface: CGRect(x: 80, y: 80, width: 220, height: 190), obstacles: controls.map(\.frame) + captions, captionHeight: 14)
    #expect(distant.isEmpty)
}
