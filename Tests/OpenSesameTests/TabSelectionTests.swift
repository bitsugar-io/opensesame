import ApplicationServices
import CoreGraphics
import Testing
import OpenSesameCore
@testable import OpenSesame

@Test func tabSelectionsNeverSubstituteTheContextMenuForAPrimaryAction() {
    #expect(TabSelection.action(role: "AXRadioButton", advertised: ["AXShowMenu", "AXPress"]) == "AXPress")
    #expect(TabSelection.action(role: "AXTabGroup", advertised: ["AXShowMenu"]) == TabSelection.groupClick)
    #expect(TabSelection.action(role: "AXTabGroup", advertised: ["AXPress", "AXShowMenu"]) == "AXPress")
    #expect(TabSelection.action(role: "AXRadioButton", advertised: ["AXShowMenu"]) == nil)
}

@Test func openingTabContentsKeepsFreshTabChoicesAsItsBackDestination() {
    let element = AXUIElementCreateApplication(0)
    let tabs = (0..<3).map { i in
        Target(element: element, frame: CGRect(x: i * 180, y: 0, width: 170, height: 32), label: "tab\(i)", kind: .tab,
            action: "AXPress", clicksMenuBarExtra: false, metadata: .init(role: "AXRadioButton", subrole: "", title: "Tab \(i)", description: "", owner: 0, bundleID: "test"))
    }
    let control = Target(element: element, frame: CGRect(x: 40, y: 90, width: 80, height: 30), label: "control", kind: .control,
        action: "AXPress", clicksMenuBarExtra: false, metadata: .init(role: "AXButton", subrole: "", title: "Fresh content", description: "", owner: 0, bundleID: "test"))
    var navigation = SectionNavigation()
    _ = navigation.reset(tabs + [control], scopedPopup: false, configuration: .standard, tabSelection: .contents)
    #expect(navigation.targets.contains { $0.metadata.title == "Fresh content" })
    #expect(navigation.depth == 0 && navigation.canGoBack)
    let returned = navigation.back()
    #expect(returned && navigation.isChoosingTabs)
    #expect(navigation.targets.map(\.metadata.title) == tabs.map(\.metadata.title))
    let pastRoot = navigation.back()
    #expect(!pastRoot)
    _ = navigation.reset(tabs + [control], scopedPopup: false, configuration: .standard, tabSelection: .choices)
    #expect(navigation.targets.count == 3 && navigation.isChoosingTabs)
}

@Test func groupHitTestingRequiresARelatedElementOrTheSameWholeWindowHost() {
    let target = AXUIElementCreateApplication(1), container = AXUIElementCreateApplication(2)
    let window = AXUIElementCreateApplication(3), child = AXUIElementCreateApplication(4)
    let unrelated = AXUIElementCreateApplication(5), host = AXUIElementCreateApplication(6)
    let header = CGRect(x: 80, y: 40, width: 90, height: 32)
    let windowFrame = CGRect(x: 0, y: 0, width: 600, height: 500)
    func read(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        if key == kAXRoleAttribute { return "AXGroup" as CFString }
        if key == kAXWindowAttribute { return window }
        if key == kAXParentAttribute {
            if CFEqual(element, target) { return container }
            if CFEqual(element, child) { return target }
        }
        return nil
    }
    func relationship(_ hit: AXUIElement, owner: pid_t = 42, frame: CGRect = CGRect(x: 0, y: 0, width: 600, height: 80), wrongWindow: Bool = false) -> String? {
        TabSelection.hitRelationship(target: target, hit: hit, frame: header, owner: 42,
            read: { element, key in
                if wrongWindow && CFEqual(element, hit) && key == kAXWindowAttribute { return unrelated }
                return read(element, key)
            }, getFrame: { element in
                CFEqual(element, window) || CFEqual(element, host) ? windowFrame : frame
            }, getOwner: { _ in owner })
    }
    #expect(relationship(target) == "target")
    #expect(relationship(child) == "descendant")
    #expect(relationship(container) == "ancestor")
    #expect(relationship(unrelated) == nil)
    #expect(relationship(host) == "window-container")
    #expect(relationship(host, wrongWindow: true) == nil)
    #expect(relationship(host, owner: 99) == nil)
    #expect(relationship(container, owner: 99) == nil)
    #expect(relationship(container, frame: CGRect(x: 0, y: 0, width: 10, height: 10)) == nil)
    #expect(relationship(container, wrongWindow: true) == nil)
}
