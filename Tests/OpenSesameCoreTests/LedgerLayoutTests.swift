import Foundation
import Testing
@testable import OpenSesameCore

@Test func ledgerOrdersRowsAndColumnsWithoutInputOrderDependence() {
    let frames = [CGRect(x: 50, y: 20, width: 20, height: 20), CGRect(x: 80, y: 60, width: 20, height: 20), CGRect(x: 10, y: 21, width: 20, height: 20)]
    #expect(LedgerLayout.labels(frames: frames) == ["s2", "a1", "s1"])
    #expect(LedgerLayout.labels(frames: []) == [])
}
@Test func ledgerCodesNeverActivateBeforeTheirFinalDigit() {
    let frames = (0..<12).map { CGRect(x: $0 * 30, y: 20, width: 20, height: 20) } + [CGRect(x: 0, y: 60, width: 20, height: 20)]
    let config = try! HintConfiguration(minimumLength: 3, alphabet: "ab", prefix: "z")
    let labels = LedgerLayout.labels(frames: frames, configuration: config)
    #expect(labels.first == "za01")
    #expect(labels.last == "zb01")
    #expect(Set(labels).count == frames.count)
    #expect(Set(labels.map(\.count)).count == 1)
    #expect(!labels.contains("za1"))
    #expect(Hints.inputCharacter("1") == "1")
    #expect(Hints.inputCharacter("A") == "a")
    #expect(Hints.inputCharacter("12") == nil)
}
@Test func ledgerRowsDoNotChainTogetherThroughVerticalJitter() {
    let frames = [0, 7, 14].map { CGRect(x: 0, y: $0, width: 20, height: 20) }
    #expect(LedgerLayout.rows(frames: frames) == [[0, 1], [2]])
}

@Test func ledgerPagesKeepEveryControlReachableAtReadableSize() {
    let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
    let popup = CGRect(x: 330, y: 60, width: 300, height: 500)
    let first = LedgerPage(items: 90, requestedPage: 0, bounds: bounds, surface: popup, fontSize: 22, codeWidth: 60)
    var covered: [Int] = []
    for number in 0..<first.count {
        let page = LedgerPage(items: 90, requestedPage: number, bounds: bounds, surface: popup, fontSize: 22, codeWidth: 60)
        covered += Array(page.range)
        #expect(bounds.contains(page.panel))
        #expect(!page.panel.intersects(popup))
        #expect(page.panel == first.panel)
    }
    #expect(covered == Array(0..<90))
    let previous = LedgerPage(items: 90, requestedPage: -1, bounds: bounds, surface: popup, fontSize: 22, codeWidth: 60)
    #expect(previous.number == first.count - 1)
    #expect(LedgerPage(items: 0, requestedPage: 12, bounds: bounds, surface: popup, fontSize: 16, codeWidth: 60).range.isEmpty)
}

@Test func overflowPanelMovesBeforeCoveringLocalHintLabels() {
    let bounds = CGRect(x: 0, y: 0, width: 1200, height: 700)
    let surface = CGRect(x: 600, y: 250, width: 30, height: 30)
    let original = LedgerPage(items: 2, requestedPage: 0, bounds: bounds, surface: surface, fontSize: 16, codeWidth: 44)
    let existingHint = original.panel.insetBy(dx: 10, dy: 10)
    let relocated = LedgerPage(items: 2, requestedPage: 0, bounds: bounds, surface: surface, fontSize: 16, codeWidth: 44, avoid: [existingHint])
    #expect(!relocated.panel.intersects(existingHint))
    #expect(bounds.contains(relocated.panel))
    #expect(relocated.range == original.range)
}

@Test func filteringKeepsOverflowFootprintAndColumnCapacity() {
    let bounds = CGRect(x: 0, y: 0, width: 1400, height: 600)
    let surface = CGRect(x: 900, y: 200, width: 200, height: 300)
    let all = LedgerPage(items: 40, layoutItems: 40, requestedPage: 0, bounds: bounds, surface: surface, fontSize: 22, codeWidth: 60)
    for count in [0, 1, 5, 20, 40] {
        let filtered = LedgerPage(items: count, layoutItems: 40, requestedPage: 10, bounds: bounds, surface: surface, fontSize: 22, codeWidth: 60)
        #expect(filtered.panel == all.panel)
        #expect(filtered.rowsPerColumn == all.rowsPerColumn)
        #expect(filtered.range.upperBound <= count)
    }
}

@Test func overflowUsesWindowRightThenLeftAndOnlyFallsInsideWhenNeitherFits() {
    let bounds = CGRect(x: 0, y: 0, width: 1600, height: 900)
    let centered = CGRect(x: 500, y: 100, width: 600, height: 700)
    func page(_ window: CGRect, _ focus: CGRect? = nil, avoid: [CGRect] = []) -> LedgerPage {
        LedgerPage(items: 12, requestedPage: 0, bounds: bounds, surface: window, fontSize: 16, codeWidth: 44, avoid: avoid, focus: focus)
    }
    let right = page(centered)
    #expect(right.panel.minX == centered.maxX + 12)
    #expect(right.panel.width == right.columnWidth)
    let blockedRight = CGRect(x: 600, y: 100, width: 900, height: 700)
    #expect(page(blockedRight).panel.maxX == blockedRight.minX - 12)
    #expect(page(blockedRight).panel.width == right.panel.width)
    let overlappingHint = right.panel.insetBy(dx: 8, dy: 8)
    #expect(page(centered, avoid: [overlappingHint]).panel.minX == right.panel.minX)
    for focus in [CGRect(x: 520, y: 650, width: 100, height: 100), CGRect(x: 900, y: 200, width: 120, height: 80)] {
        #expect(page(centered, focus).panel.minX == right.panel.minX)
    }
    let full = page(bounds, CGRect(x: 1000, y: 300, width: 400, height: 400))
    #expect(bounds.contains(full.panel))
    #expect(full.panel.maxX == 1388)
}
