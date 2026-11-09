import ApplicationServices
import Testing
import OpenSesameCore
@testable import OpenSesame

@Test func desktopDisclosureUsesAdvertisedStateWithoutDependingOnItsNameOrApp() throws {
    let element = AXUIElementCreateApplication(0)
    for role in ["AXGroup", "AXRow", "AXDisclosureTriangle"] {
        #expect(AccessibilityActionPolicy.desktopRoleIsEligible(role))
        let plan = try #require(AccessibilityActions.plan(element, role: role, kind: .desktop, advertised: ["AXShowMenu"],
            read: { _, key in key == "AXDisclosing" ? kCFBooleanTrue : nil }, writable: { _, _ in true }))
        let target = Target(element: element, frame: .zero, label: "aa", kind: .desktop, action: plan.action,
            clicksMenuBarExtra: false, metadata: .init(role: role, subrole: "", title: "スクリーンショット", description: "", owner: 0, bundleID: "test", isDisclosure: plan.isDisclosure))
        var writes = 0
        let result = AccessibilityActions.perform(target, read: { _, _ in kCFBooleanTrue }, writable: { _, _ in true },
            write: { _, key, value in
                #expect(key == "AXDisclosing" && CFEqual(value, kCFBooleanFalse)); writes += 1; return .success
            }, press: { _, _ in Issue.record("A disclosure must not open its context menu"); return .failure })
        #expect(result == .success && writes == 1 && plan.isDisclosure)
        let stale = AccessibilityActions.perform(target, read: { _, _ in nil }, writable: { _, _ in true },
            write: { _, _, _ in Issue.record("Missing state must not be guessed"); return .failure })
        #expect(stale == .attributeUnsupported)
    }
}

@Test func desktopFilesKeepOpenAndContextOnlyContainersDoNotBecomeOpenTargets() {
    #expect(AccessibilityActionPolicy.primary(role: "AXImage", kind: .desktop, advertised: ["AXShowMenu", "AXOpen"]) == "AXOpen")
    #expect(AccessibilityActionPolicy.primary(role: "AXGroup", kind: .desktop, advertised: ["AXShowMenu"]) == nil)
    #expect(!AccessibilityActionPolicy.desktopRoleIsEligible("AXWindow"))
    #expect(TargetExclusion.excludes(role: "AXButton", subrole: "AXZoomButton", title: "", description: "", kind: .desktop))
}

@Test func passiveControlsDoNotSpendScanTimeProbingDisclosureState() {
    let element = AXUIElementCreateApplication(0)
    let plan = AccessibilityActions.plan(element, role: "AXStaticText", kind: .control, advertised: [], read: { _, _ in
        Issue.record("Passive text does not need a disclosure-state round trip"); return nil
    })
    #expect(plan == nil)
}

@Test func disclosureSkipsReadOnlyExpandedStateForWritableDisclosingState() throws {
    let plan = try #require(AccessibilityActions.plan(AXUIElementCreateApplication(0), role: "AXGroup", kind: .control,
        advertised: ["AXShowMenu"], read: { _, _ in kCFBooleanFalse }, writable: { _, key in key == "AXDisclosing" }))
    #expect(plan.action == AccessibilityActionPolicy.togglePrefix + "AXDisclosing")
    #expect(plan.isDisclosure)
}
