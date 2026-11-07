import ApplicationServices
import Testing
@testable import OpenSesame

@Test func alternateNavigationChildrenWorkForAnyProviderAndLeavesStayCheap() {
    let parent = AXUIElementCreateApplication(0), child = AXUIElementCreateApplication(1)
    for role in ["AXWindow", "AXGroup", "AXWebArea", "AXTabGroup", "AXRow"] {
        let result = AccessibilityTraversal.children(of: parent, role: role, read: { _, key in
            key == "AXChildrenInNavigationOrder" ? [child] as CFArray : [] as CFArray
        })
        #expect(result.count == 1 && CFEqual(result[0], child))
    }
    let result = AccessibilityTraversal.children(of: parent, role: "AXStaticText", read: { _, key in
        #expect(key == kAXChildrenAttribute)
        return nil
    })
    #expect(result.isEmpty)
}

@Test func visibleMenusAndOrdinaryChildrenAreAuthoritative() {
    let parent = AXUIElementCreateApplication(0), child = AXUIElementCreateApplication(1)
    let emptyMenu = AccessibilityTraversal.children(of: parent, role: "AXMenu", read: { _, key in
        #expect(key == kAXVisibleChildrenAttribute)
        return [] as CFArray
    })
    #expect(emptyMenu.isEmpty)
    let children = AccessibilityTraversal.children(of: parent, role: "AXGroup", read: { _, key in
        #expect(key == kAXChildrenAttribute)
        return [child] as CFArray
    })
    #expect(children.count == 1 && CFEqual(children[0], child))
    let contents = AccessibilityTraversal.children(of: parent, role: "AXGroup", read: { _, key in
        key == kAXContentsAttribute ? [child] as CFArray : nil
    })
    #expect(contents.count == 1 && CFEqual(contents[0], child))
}
