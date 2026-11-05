import CoreGraphics
import Testing
@testable import OpenSesameCore

@Test func nativeAlternateItemsCollapseToOneVisibleRow() {
    let row = MenuRow(owner: 1, frame: CGRect(x: 0, y: 20, width: 240, height: 22))
    let alternate = MenuRow(owner: 1, frame: row.frame)
    let label = MenuRow(owner: 1, frame: CGRect(x: 20, y: 23, width: 120, height: 16))
    #expect(row.sharesVisibleRow(with: alternate))
    #expect(row.sharesVisibleRow(with: label))
}
@Test func adjacentRowsAndSeparateMenusStayDistinct() {
    let row = MenuRow(owner: 1, frame: CGRect(x: 0, y: 20, width: 240, height: 22))
    #expect(!row.sharesVisibleRow(with: MenuRow(owner: 1, frame: row.frame.offsetBy(dx: 0, dy: 22))))
    #expect(!row.sharesVisibleRow(with: MenuRow(owner: 1, frame: row.frame.offsetBy(dx: 240, dy: 0))))
    #expect(!row.sharesVisibleRow(with: MenuRow(owner: 2, frame: row.frame)))
}
