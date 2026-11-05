import Foundation
import CoreGraphics
import Testing
@testable import OpenSesameCore

private func surface(_ id: UInt32, _ pid: Int32, _ x: CGFloat = 0) -> Surface {
    Surface(id: id, pid: pid, frame: CGRect(x: x, y: 20, width: 300, height: 200))
}
@Test func openedPanelExcludesExistingWindowsAndUnrelatedApps() {
    let existing = surface(1, 10), panel = surface(2, 20), unrelated = surface(3, 30)
    #expect(Surface.opened(before: [existing], after: [unrelated, panel, existing], owners: [10, 20]) == panel)
    #expect(Surface.opened(before: [existing], after: [unrelated, existing], owners: [10, 20]) == nil)
}
@Test func reusedPopupWindowAndNewAppDialogAreDetected() {
    let old = surface(1, 10), moved = surface(1, 10, 200), about = surface(2, 40)
    #expect(Surface.opened(before: [old], after: [moved], owners: [10]) == moved)
    #expect(Surface.opened(before: [old], after: [about, old], owners: [10, 40]) == about)
    #expect(Surface.opened(before: [old], after: [old], owners: [10]) == nil)
}

@Test func openingSettingsCanReuseAnExistingWindow() {
    let terminal = surface(1, 10), settings = surface(2, 40)
    #expect(Surface.opened(before: [terminal, settings], after: [settings, terminal], owners: [10, 40], activatedOwner: 40) == settings)
    #expect(Surface.opened(before: [terminal, settings], after: [settings, terminal], owners: [10], activatedOwner: 40) == nil)
}

@Test func nativeMenuDetectionExcludesTooltipsAndRespectsExtraAppOwners() {
    let menu = Surface(id: 5, pid: 20, frame: CGRect(x: 10, y: 20, width: 200, height: 300), layer: 101)
    let tooltip = Surface(id: 6, pid: 10, frame: menu.frame, layer: 102)
    let unrelated = Surface(id: 7, pid: 30, frame: menu.frame, layer: 101)
    #expect(Surface.menus(in: [tooltip, unrelated, menu], owners: [10, 20], menuLayer: 101) == [menu])
    #expect(Surface.menus(in: [menu], owners: [10], menuLayer: 101).isEmpty)
}

@Test func newPopupWinsOverExistingFocusedWindow() {
    let terminal = surface(1, 10)
    let controlCenter = surface(2, 20)
    let wifi = surface(3, 20)
    #expect(Surface.opened(before: [terminal, controlCenter], after: [terminal, wifi], owners: [10, 20], activatedOwner: 10) == wifi)
    // The same popup window may be reused with new bounds.
    let resized = surface(2, 20, 200)
    #expect(Surface.opened(before: [terminal, controlCenter], after: [terminal, resized], owners: [10, 20], activatedOwner: 10) == resized)
}
