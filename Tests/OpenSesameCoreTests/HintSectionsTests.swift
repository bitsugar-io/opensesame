import CoreGraphics
import Testing
@testable import OpenSesameCore

@Test func crowdedSectionsPreserveEveryActionExactlyOnce() {
    let frames = (0..<133).map { CGRect(x: ($0 % 12) * 60, y: ($0 / 12) * 50, width: 30, height: 25) }
    let sections = HintSections.make(frames: frames)
    #expect(sections.count <= 16)
    #expect(sections.allSatisfy { $0.indices.count <= 18 })
    #expect(sections.flatMap(\.indices).sorted() == Array(frames.indices))
    #expect(sections.allSatisfy { section in section.indices.allSatisfy { section.frame.contains(frames[$0]) } })
}
@Test func sparseWindowsRemainDirectAndCoincidentControlsTerminate() {
    #expect(HintSections.make(frames: Array(repeating: CGRect(x: 0, y: 0, width: 20, height: 20), count: 40)).isEmpty)
    let sections = HintSections.make(frames: Array(repeating: CGRect(x: 0, y: 0, width: 20, height: 20), count: 60))
    #expect(sections.flatMap(\.indices).count == 60)
    #expect(sections.allSatisfy { $0.indices.count <= 18 })
}
