import CoreGraphics
import Testing
@testable import OpenSesameCore

@Test func sidebarCellAndButtonCollapseOnlyWhenTheyShareActionAndAncestry() {
    let button = CGRect(x: 690, y: 645, width: 220, height: 38)
    let cell = CGRect(x: 700, y: 645, width: 200, height: 38)
    #expect(ActionDuplicate.matches(owner: 10, otherOwner: 10, name: "Discover", otherName: "Discover", frame: button, otherFrame: cell, related: true))
    #expect(!ActionDuplicate.matches(owner: 10, otherOwner: 10, name: "Discover", otherName: "Discover", frame: button, otherFrame: cell, related: false))
    #expect(!ActionDuplicate.matches(owner: 10, otherOwner: 20, name: "Discover", otherName: "Discover", frame: button, otherFrame: cell, related: true))
    #expect(!ActionDuplicate.matches(owner: 10, otherOwner: 10, name: "Discover", otherName: "Arcade", frame: button, otherFrame: cell, related: true))
    #expect(!ActionDuplicate.matches(owner: 10, otherOwner: 10, name: "", otherName: "", frame: button, otherFrame: cell, related: true))
}
