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
