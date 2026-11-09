import Testing
@testable import OpenSesameCore

@Test func menuRowsExcludeNestedLabelsAndUnopenedSubmenus() {
    // Use the production traversal rule on a menu containing an actionable row,
    // a redundant label, a shortcut node, and a hidden submenu with a stale frame.
    struct Node {
        let role: String
        let actionable: Bool
        var children: [Node] = []
    }
    let menu = Node(role: "AXMenu", actionable: false, children: [
        Node(role: "AXMenuItem", actionable: true, children: [
            Node(role: "AXStaticText", actionable: true),
            Node(role: "AXImage", actionable: true),
            Node(role: "AXMenu", actionable: false, children: [Node(role: "AXMenuItem", actionable: true)])
        ]),
        Node(role: "AXMenuItem", actionable: true)
    ])
    func count(_ node: Node) -> Int {
        (node.actionable ? 1 : 0) + (MenuTraversal.descendsInto(role: node.role) ? node.children.map(count).reduce(0, +) : 0)
    }
    #expect(count(menu) == 2)
    #expect(!MenuTraversal.descendsInto(role: "AXMenuBarItem"))
    #expect(MenuTraversal.descendsInto(role: "AXGroup"))
}
@Test func tabsAndCloseDoNotUsePopupFollowing() {
    #expect(!TargetKind.tab.followsOpenedSurface)
    #expect(!TargetKind.close.followsOpenedSurface)
    #expect(TargetKind.menu.followsOpenedSurface)
    #expect(TargetKind.control.followsOpenedSurface)
}

@Test func customMenuRowsExposeEmbeddedControlsWithoutLabelsOrSubmenus() {
    for role in ["AXGroup", "AXCheckBox", "AXSwitch", "AXButton", "AXRadioButton"] {
        #expect(MenuTraversal.allowsEmbedded(role: role))
    }
    for role in ["AXStaticText", "AXImage", "AXMenu", "AXMenuItem", "AXMenuBarItem"] {
        #expect(!MenuTraversal.allowsEmbedded(role: role))
    }
}
