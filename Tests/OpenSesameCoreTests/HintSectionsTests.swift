import CoreGraphics
import Testing
@testable import OpenSesameCore

@Test func crowdedSectionsPreserveEveryActionExactlyOnce() {
    let frames = (0..<133).map { CGRect(x: ($0 % 12) * 60, y: ($0 / 12) * 50, width: 30, height: 25) }
    let sections = HintSections.make(frames: frames)
    #expect(sections.count == 3)
    #expect(sections.flatMap(\.indices).sorted() == Array(frames.indices))
    #expect(sections.allSatisfy { section in section.indices.allSatisfy { section.frame.contains(frames[$0]) } })
    for (index, section) in sections.enumerated() {
        #expect(!sections.dropFirst(index + 1).contains { section.frame.intersects($0.frame) })
    }
}
@Test func sparseWindowsAndInseparableControlsRemainDirect() {
    #expect(HintSections.make(frames: Array(repeating: CGRect(x: 0, y: 0, width: 20, height: 20), count: 40)).isEmpty)
    let sections = HintSections.make(frames: Array(repeating: CGRect(x: 0, y: 0, width: 20, height: 20), count: 60))
    #expect(sections.isEmpty)
}

@Test func sectionsFollowUnequalPanelsInsteadOfCuttingThemIntoEqualCounts() {
    let sidebar = (0..<16).map { CGRect(x: 48, y: 96 + $0 * 26, width: 140, height: 20) }
    let toolbar = (0..<8).map { CGRect(x: 316 + $0 * 72, y: 96, width: 42, height: 28) }
    let content = (0..<12).map { CGRect(x: 316 + $0 % 4 * 152, y: 226 + $0 / 4 * 82, width: 116, height: 30) }
    let composer = (0..<8).map { CGRect(x: 316 + $0 * 72, y: 562, width: 42, height: 28) }
    let groups = [sidebar, toolbar, content, composer]
    let frames = groups.flatMap { $0 }
    let sections = HintSections.make(frames: frames)
    #expect(sections.count == 3)
    // Toolbar and content remain one region until selected. The outer page
    // must not show all four detailed groups at once.
    let expectedGroups = [sidebar, toolbar + content, composer]
    #expect(sections.map(\.frame) == expectedGroups.map { $0.reduce(CGRect.null) { $0.union($1) } })
    #expect(sections.map { $0.indices.count } == [16, 20, 8])
    // Discovery traversal order and desktop offsets must not alter membership.
    let reordered = HintSections.make(frames: frames.reversed())
    #expect(reordered.map(\.frame) == sections.map(\.frame))
    let offset = HintSections.make(frames: frames.map { $0.offsetBy(dx: -1400, dy: 800) })
    #expect(offset.map(\.frame) == sections.map { $0.frame.offsetBy(dx: -1400, dy: 800) })
}

@Test func repeatedDrillDownKeepsEveryLevelAtMostThreeAndEveryActionReachable() {
    let frames = (0..<400).map { CGRect(x: $0 % 20 * 50, y: $0 / 20 * 50, width: 24, height: 24) }
    var leaves: [CGRect] = []
    var deepest = 0
    func visit(_ frames: [CGRect], depth: Int) {
        let sections = HintSections.make(frames: frames, threshold: depth == 0 ? 40 : 18)
        deepest = max(deepest, depth)
        guard !sections.isEmpty else {
            #expect(frames.count <= 18)
            leaves += frames
            return
        }
        #expect((2...3).contains(sections.count))
        for section in sections {
            #expect(section.indices.count < frames.count)
            visit(section.indices.map { frames[$0] }, depth: depth + 1)
        }
    }
    visit(frames, depth: 0)
    #expect(deepest >= 3)
    #expect(leaves.count == frames.count)
    #expect(frames.allSatisfy { frame in leaves.filter { $0 == frame }.count == 1 })
}

@Test func wideAndNestedControlsDoNotProduceOverlappingSectionBoxes() {
    let dense = Array(repeating: CGRect(x: 20, y: 80, width: 500, height: 260), count: 30)
        + (0..<6).map { CGRect(x: 60 + $0 * 55, y: 100, width: 28, height: 28) }
    let separate = (0..<12).map { CGRect(x: 600 + $0 % 3 * 70, y: 80 + $0 / 3 * 60, width: 30, height: 25) }
    let frames = dense + separate
    let sections = HintSections.make(frames: frames)
    #expect(sections.count == 2)
    #expect(sections.first?.indices.count == 36)
    #expect(sections.flatMap(\.indices).sorted() == Array(frames.indices))
    #expect(!sections[0].frame.intersects(sections[1].frame))
}

@Test func sectionPanesReachWindowEdgesWithoutAddingControlsInEmptyAreas() {
    let window = CGRect(x: 100, y: 200, width: 1200, height: 900)
    let frames = (0..<60).map { index in
        CGRect(x: 140 + index % 10 * 100, y: 260 + index / 10 * 90, width: 36, height: 30)
    }
    let sections = HintSections.make(frames: frames, bounds: window)
    #expect(sections.count == 3)
    #expect(sections.flatMap(\.indices).sorted() == Array(frames.indices))
    #expect(sections.reduce(CGRect.null) { $0.union($1.frame) } == window)
    #expect(sections.contains { $0.frame.maxY == window.maxY })
    for (index, section) in sections.enumerated() {
        #expect(window.contains(section.frame))
        #expect(section.indices.allSatisfy { section.frame.contains(frames[$0]) })
        #expect(!sections.dropFirst(index + 1).contains { section.frame.intersects($0.frame) })
    }
    let shifted = HintSections.make(frames: frames.map { $0.offsetBy(dx: -1500, dy: 300) }, bounds: window.offsetBy(dx: -1500, dy: 300))
    #expect(shifted.map(\.frame) == sections.map { $0.frame.offsetBy(dx: -1500, dy: 300) })
}

@Test func childPanesKeepTheSelectedBoundaryAndDoNotCreateEmptyChoices() {
    let window = CGRect(x: 0, y: 0, width: 1200, height: 1000)
    let frames = (0..<180).map { CGRect(x: 40 + $0 % 15 * 70, y: 50 + $0 / 15 * 60, width: 24, height: 24) }
    let roots = HintSections.make(frames: frames, bounds: window)
    for root in roots {
        let members = root.indices.map { frames[$0] }
        let children = HintSections.make(frames: members, threshold: 18, bounds: root.frame)
        #expect(!children.isEmpty && children.count <= 3)
        #expect(children.reduce(CGRect.null) { $0.union($1.frame) } == root.frame)
        #expect(children.flatMap(\.indices).sorted() == Array(members.indices))
    }
    #expect(HintSections.make(frames: [], bounds: window).isEmpty)
}
