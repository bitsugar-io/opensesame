import CoreGraphics
import Testing
@testable import OpenSesameCore

@Test func partiallyCoveredWindowsKeepOnlyExposedTopBottomAndSideStrips() {
    let frame = CGRect(x: 100, y: 100, width: 700, height: 600)
    let front = CGRect(x: 100, y: 170, width: 700, height: 430)
    let exposed = VisibleRegion.exposed(frame: frame, screens: [CGRect(x: 0, y: 0, width: 1000, height: 800)], occluders: [front])
    #expect(exposed == [CGRect(x: 100, y: 100, width: 700, height: 70), CGRect(x: 100, y: 600, width: 700, height: 100)])
    #expect(exposed.allSatisfy { !front.intersects($0.insetBy(dx: 0.1, dy: 0.1)) })
}

@Test func fullyCoveredAndOffscreenWindowsHaveNoExposedRegion() {
    let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let frame = CGRect(x: 100, y: 100, width: 700, height: 600)
    #expect(VisibleRegion.exposed(frame: frame, screens: [screen], occluders: [frame]).isEmpty)
    #expect(VisibleRegion.exposed(frame: frame.offsetBy(dx: 1200, dy: 0), screens: [screen], occluders: []).isEmpty)
}

@Test func exposureRespectsMultipleOverlapsAndOffsetDisplays() {
    let screen = CGRect(x: -1200, y: 200, width: 1200, height: 800)
    let frame = CGRect(x: -1000, y: 250, width: 900, height: 650)
    let blockers = [CGRect(x: -1000, y: 250, width: 500, height: 400), CGRect(x: -600, y: 550, width: 500, height: 350)]
    let exposed = VisibleRegion.exposed(frame: frame, screens: [screen], occluders: blockers)
    #expect(!exposed.isEmpty)
    for rect in exposed {
        #expect(frame.contains(rect) && screen.contains(rect))
        #expect(blockers.allSatisfy { !$0.intersects(rect.insetBy(dx: 0.1, dy: 0.1)) })
    }
}
