import Testing
@testable import OpenSesameCore

@Test func tabCloseAndMenuActionsHaveDistinctMarkers() {
    #expect(TargetKind.classify(role: "AXRadioButton", subrole: "", parentRole: "AXTabGroup", description: "Shell") == .tab)
    #expect(TargetKind.classify(role: "AXButton", subrole: "AXCloseButton", parentRole: "AXTabGroup", description: "") == .close)
    #expect(TargetKind.classify(role: "AXButton", subrole: "", parentRole: "", description: "close tab") == .close)
    #expect(TargetKind.classify(role: "AXMenuItem", subrole: "", parentRole: "AXMenu", description: "About") == .menu)
    #expect(TargetKind.classify(role: "AXRadioButton", subrole: "", parentRole: "AXGroup", description: "Option") == .control)
    #expect(Set([TargetKind.tab.marker, TargetKind.close.marker, TargetKind.menu.marker]).count == 3)
}
@Test func duplicateIdentityPreservesDifferentControlsAtSamePosition() {
    func identity(pid: Int32 = 1, name: String = "Tab", kind: TargetKind = .tab, action: String = "AXPress") -> TargetIdentity {
        TargetIdentity(pid: pid, role: "AXButton", name: name, action: action, kind: kind, x: 10, y: 20, width: 100, height: 25)
    }
    #expect(Set([identity(), identity()]).count == 1)
    #expect(Set([identity(), identity(name: "Close", kind: .close), identity(pid: 2), identity(action: "AXShowMenu")]).count == 4)
}

@Test func selectingAWindowEndsHintsLikeSelectingATab() {
    #expect(!TargetKind.window.followsOpenedSurface)
    #expect(TargetKind.window.marker != TargetKind.tab.marker)
    #expect(!TargetExclusion.excludes(role: "AXWindow", subrole: "AXStandardWindow", title: "Shell", description: "Switch window", kind: .window))
}
