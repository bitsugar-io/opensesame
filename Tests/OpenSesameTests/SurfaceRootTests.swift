import ApplicationServices
import CoreGraphics
import Testing
@testable import OpenSesame

private struct MenuFixture {
    let app = AXUIElementCreateApplication(910001)
    let focused = AXUIElementCreateApplication(910002)
    let menuBar = AXUIElementCreateApplication(910003)
    let menu = AXUIElementCreateApplication(910004)
    let stale = AXUIElementCreateApplication(910005)
    let bounds = CGRect(x: 4805, y: 176, width: 249, height: 437)
    func frame(_ element: AXUIElement) -> CGRect? {
        if CFEqual(element, menu) { return bounds }
        if CFEqual(element, stale) { return bounds.offsetBy(dx: -1000, dy: 0) }
        return nil
    }
    func resolve(source: AXUIElement? = nil, read: (AXUIElement, String) -> CFTypeRef?) -> AXUIElement? {
        surfaceRoot(app: app, windows: [], surface: bounds, openedFrom: source,
            deadline: Date().addingTimeInterval(1), read: read, frame: frame)
    }
}

@Test func selectedWindowScanKeepsAppMenusWithoutSubstitutingTheFocusedWindow() {
    let f = MenuFixture()
    var keys: [String] = []
    let selected = Discovery.closedSurfaceRoots(app: f.app, popupOnly: false, menuBarFallback: false,
        requestedWindow: f.stale, read: { _, key in
            keys.append(key)
            return key == kAXMenuBarAttribute ? f.menuBar : f.focused
        })
    #expect(selected.window.map { CFEqual($0, f.stale) } == true)
    #expect(selected.menu.map { CFEqual($0, f.menuBar) } == true)
    #expect(keys == [kAXMenuBarAttribute])
}

@Test func menuBarExpansionRefreshesMenusWithoutFallingBackToBackgroundWindowControls() {
    let f = MenuFixture()
    var keys: [String] = []
    func read(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        keys.append(key)
        return key == kAXMenuBarAttribute ? f.menuBar : f.focused
    }
    let menus = Discovery.closedSurfaceRoots(app: f.app, popupOnly: true, menuBarFallback: true, read: read)
    #expect(menus.window == nil && menus.menu.map { CFEqual($0, f.menuBar) } == true)
    #expect(keys == [kAXMenuBarAttribute])
    keys = []
    let popup = Discovery.closedSurfaceRoots(app: f.app, popupOnly: true, menuBarFallback: false, read: read)
    #expect(popup.window == nil && popup.menu == nil && keys.isEmpty)
}

@Test func contextMenuOutsideMenuBarResolvesForFreshAndFollowupScans() {
    let f = MenuFixture()
    func read(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        if CFEqual(element, f.app) {
            if key == kAXFocusedUIElementAttribute { return f.focused }
            if key == kAXMenuBarAttribute { return f.menuBar }
            if key == kAXVisibleChildrenAttribute { return [] as CFArray }
            if key == kAXChildrenAttribute { return [f.menuBar, f.menu] as CFArray }
        }
        if CFEqual(element, f.menu), key == kAXRoleAttribute { return "AXMenu" as CFString }
        return nil
    }
    #expect(f.resolve(read: read).map { CFEqual($0, f.menu) } == true)
    #expect(f.resolve(source: f.focused, read: read).map { CFEqual($0, f.menu) } == true)
}

@Test func shownMenuLinksResolveWithoutChildEnumeration() {
    let f = MenuFixture()
    let root = f.resolve(source: f.focused) { element, key in
        if CFEqual(element, f.focused), key == kAXShownMenuUIElementAttribute { return f.menu }
        return nil
    }
    #expect(root.map { CFEqual($0, f.menu) } == true)
}

@Test func contextSearchRejectsHiddenAndUnrelatedMenus() {
    let f = MenuFixture()
    let root = f.resolve { element, key in
        if CFEqual(element, f.app), key == kAXChildrenAttribute { return [f.stale, f.menu] as CFArray }
        if key == kAXRoleAttribute { return "AXMenu" as CFString }
        if CFEqual(element, f.menu), key == kAXHiddenAttribute { return kCFBooleanTrue }
        return nil
    }
    #expect(root == nil)
}

@Test func knownPopoverWindowRemainsPreferredOverAppTraversal() {
    let f = MenuFixture()
    var reads = 0
    let root = surfaceRoot(app: f.app, windows: [f.menu], surface: f.bounds, openedFrom: nil,
        deadline: Date().addingTimeInterval(1), read: { _, _ in reads += 1; return nil }, frame: f.frame)
    #expect(root.map { CFEqual($0, f.menu) } == true)
    #expect(reads == 0)
}

@Test func unenumeratedNativeMenuCanResolveFromAXHitTestWithoutClicking() {
    let f = MenuFixture()
    let read: (AXUIElement, String) -> CFTypeRef? = { element, key in
        if CFEqual(element, f.focused), key == kAXParentAttribute { return f.menu }
        if CFEqual(element, f.menu), key == kAXRoleAttribute { return kAXMenuRole as CFString }
        return nil
    }
    let root = surfaceRoot(app: f.app, windows: [], surface: f.bounds, openedFrom: nil,
        deadline: Date().addingTimeInterval(1), read: read, frame: f.frame, hitTest: { _, point in
            #expect(f.bounds.contains(point)); return f.focused
        })
    #expect(root.map { CFEqual($0, f.menu) } == true)
    let mismatch = surfaceRoot(app: f.app, windows: [], surface: f.bounds.offsetBy(dx: 1000, dy: 0), openedFrom: nil,
        deadline: Date().addingTimeInterval(1), read: read, frame: f.frame, hitTest: { _, _ in f.focused })
    #expect(mismatch == nil)
}

@Test func transparentPopupHostDoesNotPublishLabelsAfterItsControlsDisappear() {
    let f = MenuFixture()
    let read: (AXUIElement, String) -> CFTypeRef? = { element, key in
        if CFEqual(element, f.menu), key == kAXChildrenAttribute { return [f.focused] as CFArray }
        if CFEqual(element, f.focused) {
            if key == kAXRoleAttribute { return "AXButton" as CFString }
            if key == kAXParentAttribute { return f.menu }
        }
        return nil
    }
    let frame: (AXUIElement) -> CGRect? = { _ in f.bounds }
    #expect(hasExposedPopupControl(f.menu, deadline: Date().addingTimeInterval(1), read: read, frame: frame, hit: { _ in f.focused }))
    #expect(!hasExposedPopupControl(f.menu, deadline: Date().addingTimeInterval(1), read: read, frame: frame, hit: { _ in f.stale }))
}

@Test func sameWindowPopupIsFoundThroughFocusedControlAncestors() {
    let f = MenuFixture()
    let root = shownPopup(app: f.app, openedFrom: f.menuBar, deadline: Date().addingTimeInterval(1), read: { element, key in
        if CFEqual(element, f.app), key == kAXFocusedUIElementAttribute { return f.focused }
        if CFEqual(element, f.focused), key == kAXParentAttribute { return f.menu }
        if CFEqual(element, f.menu), key == kAXRoleAttribute { return "AXMenu" as CFString }
        return nil
    }, frame: f.frame)
    #expect(root.map { CFEqual($0, f.menu) } == true)
}

@Test func ordinaryFocusedWindowDoesNotRestartHintsAfterAnAction() {
    let f = MenuFixture()
    let root = shownPopup(app: f.app, openedFrom: f.focused, deadline: Date().addingTimeInterval(1), read: { element, key in
        if CFEqual(element, f.app), key == kAXFocusedUIElementAttribute { return f.focused }
        if CFEqual(element, f.focused), key == kAXRoleAttribute { return "AXWindow" as CFString }
        return nil
    }, frame: { _ in f.bounds })
    #expect(root == nil)
}

@Test func closedSourceMenuIsNotReusedFromStaleParentCoordinates() {
    let f = MenuFixture()
    let root = shownPopup(app: f.app, openedFrom: f.focused, deadline: Date().addingTimeInterval(1), read: { element, key in
        if CFEqual(element, f.focused), key == kAXParentAttribute { return f.menu }
        if CFEqual(element, f.menu), key == kAXRoleAttribute { return "AXMenu" as CFString }
        return nil
    }, frame: f.frame)
    #expect(root == nil)
}

@Test func focusedMenuItemParentRemainsAValidNativeMenuRoot() {
    let f = MenuFixture()
    let root = f.resolve { element, key in
        if CFEqual(element, f.app), key == kAXFocusedUIElementAttribute { return f.focused }
        if CFEqual(element, f.focused), key == kAXParentAttribute { return f.menu }
        if CFEqual(element, f.menu), key == kAXRoleAttribute { return "AXMenu" as CFString }
        return nil
    }
    #expect(root.map { CFEqual($0, f.menu) } == true)
}

@Test func passiveMenuLevelBannerDoesNotQualifyAsPopup() {
    let f = MenuFixture()
    let read: (AXUIElement, String) -> CFTypeRef? = { element, key in
        if key == kAXRoleAttribute { return (CFEqual(element, f.app) ? "AXWindow" : "AXGroup") as CFString }
        if CFEqual(element, f.app), key == kAXChildrenAttribute { return [f.focused, f.menuBar] as CFArray }
        return nil
    }
    #expect(hasPopupControls(f.app, deadline: Date().addingTimeInterval(1), read: read, actions: { _ in [] }) == false)
    #expect(hasPopupControls(f.app, deadline: Date().addingTimeInterval(-1), read: read, actions: { _ in [] }) == nil)
    #expect(hasPopupControls(f.app, deadline: Date().addingTimeInterval(1), read: read,
        actions: { CFEqual($0, f.focused) ? ["AXPress"] : [] }) == true)
}
