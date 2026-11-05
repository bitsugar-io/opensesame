import CoreGraphics
import Testing
@testable import OpenSesameCore

@Test func visibleWindowsMatchDistinctCascadedSurfaces() {
    let a = CGRect(x: 100, y: 100, width: 600, height: 500)
    let b = a.offsetBy(dx: 20, dy: 20)
    #expect(WindowMatching.visibleIndices(windows: [a, b], surfaces: [b, a]) == [0, 1])
    #expect(WindowMatching.visibleIndices(windows: [a, b], surfaces: [a]) == [])
}
@Test func ambiguousOtherSpaceWindowsAreNotOffered() {
    let a = CGRect(x: 100, y: 100, width: 600, height: 500)
    let b = a.offsetBy(dx: 700, dy: 0)
    #expect(WindowMatching.visibleIndices(windows: [a, a, b], surfaces: [a, b]) == [2])
    #expect(WindowMatching.visibleIndices(windows: [a, b], surfaces: [a, a, b]) == [1])
}
