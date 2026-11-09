import CoreGraphics
import Testing
@testable import OpenSesameCore

@Test func regionCodesCenterInUncoveredPanesAndChooseTheLargerExposedStrip() throws {
    let bounds = CGRect(x: 0, y: 0, width: 1200, height: 900)
    let region = CGRect(x: 100, y: 100, width: 700, height: 600)
    let centered = try #require(RegionMarkerLayout.place(region: region, visible: [region], aspectRatio: 1.5, fontSize: 16, bounds: bounds, occupied: []))
    #expect(centered.midX == region.midX && centered.midY == region.midY)
    #expect(centered.height == 64)
    let exposed = [CGRect(x: 100, y: 100, width: 700, height: 70), CGRect(x: 100, y: 590, width: 700, height: 110)]
    let marker = try #require(RegionMarkerLayout.place(region: region, visible: exposed, aspectRatio: 1.5, fontSize: 16, bounds: bounds, occupied: []))
    #expect(exposed[1].contains(marker))
    #expect(marker.midX == region.midX)
}

@Test func regionCodesAvoidOtherCodesAndStayInExposedSpaceOnOffsetDisplays() throws {
    let region = CGRect(x: -900, y: 120, width: 700, height: 600)
    let bounds = CGRect(x: -1000, y: 0, width: 1000, height: 900)
    let first = try #require(RegionMarkerLayout.place(region: region, visible: [region], aspectRatio: 2.5, fontSize: 22, bounds: bounds, occupied: []))
    let second = try #require(RegionMarkerLayout.place(region: region, visible: [region], aspectRatio: 2.5, fontSize: 22, bounds: bounds, occupied: [first]))
    #expect(region.contains(first) && region.contains(second))
    #expect(!first.insetBy(dx: -7, dy: -7).intersects(second))
    #expect(RegionMarkerLayout.place(region: region, visible: [], aspectRatio: 1, fontSize: 16, bounds: bounds, occupied: []) == nil)
}

@Test func narrowSectionsExpandOnlyWhenTheirPaneWillRemainDistinct() {
    let bounds = CGRect(x: 0, y: 0, width: 1000, height: 700)
    let strip = CGRect(x: 100, y: 100, width: 500, height: 28)
    #expect(RegionMarkerLayout.sectionFrame(strip, bounds: bounds, neighbors: []).height == 96)
    let neighbor = strip.offsetBy(dx: 0, dy: 68)
    let first = RegionMarkerLayout.sectionFrame(strip, bounds: bounds, neighbors: [neighbor])
    let second = RegionMarkerLayout.sectionFrame(neighbor, bounds: bounds, neighbors: [strip])
    #expect(!first.intersects(second))
}
