import CoreGraphics
import Testing
@testable import OpenSesameCore

@Test func animatedControlFramesAllowLocalSettlingButRejectRelocation() {
    let before = CGRect(x: 4813.2478, y: 40.7532, width: 140.7213, height: 64.3297)
    #expect(TargetGeometry.isStable(previous: before, current: CGRect(x: 4813, y: 41, width: 141, height: 64)))
    #expect(TargetGeometry.isStable(previous: before, current: before.offsetBy(dx: 2, dy: 3)))
    #expect(!TargetGeometry.isStable(previous: before, current: before.offsetBy(dx: 40, dy: 0)))
    #expect(!TargetGeometry.isStable(previous: before, current: CGRect(x: 4813, y: 41, width: 70, height: 64)))
    #expect(!TargetGeometry.isStable(previous: before, current: .zero))
}

@Test func scrolledContentOutsideTheFocusedWindowIsNotATarget() {
    let window = CGRect(x: 100, y: 100, width: 800, height: 600)
    #expect(TargetGeometry.isVisible(frame: CGRect(x: 200, y: 200, width: 40, height: 30), viewport: window))
    #expect(!TargetGeometry.isVisible(frame: CGRect(x: 200, y: 800, width: 40, height: 30), viewport: window))
    #expect(!TargetGeometry.isVisible(frame: CGRect(x: 950, y: 200, width: 40, height: 30), viewport: window))
}
