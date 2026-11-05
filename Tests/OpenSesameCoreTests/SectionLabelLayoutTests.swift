import CoreGraphics
import Testing
@testable import OpenSesameCore

@Test func sectionLabelsMoveToClearGuttersWithoutOverlappingOtherLabels() throws {
    let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
    let section = CGRect(x: 100, y: 100, width: 400, height: 300)
    let text = CGRect(x: 95, y: 400, width: 420, height: 50)
    let candidates = SectionLabelLayout.candidates(section: section, badge: CGSize(width: 180, height: 30), bounds: bounds)
        .filter { !$0.intersects(text) }
    let first = try #require(BadgeLayout.place(candidates: candidates, bounds: bounds, occupied: [], controls: []))
    let second = try #require(BadgeLayout.place(candidates: candidates, bounds: bounds, occupied: [first], controls: []))
    #expect(!first.intersects(second))
    #expect(!first.intersects(text) && !second.intersects(text))
    #expect(bounds.contains(first) && bounds.contains(second))
}

@Test func sectionCaptionTooWideForDisplayRequestsOverflowInsteadOfClipping() {
    #expect(SectionLabelLayout.candidates(section: CGRect(x: 20, y: 20, width: 80, height: 80),
        badge: CGSize(width: 400, height: 30), bounds: CGRect(x: 0, y: 0, width: 300, height: 200)).isEmpty)
}
