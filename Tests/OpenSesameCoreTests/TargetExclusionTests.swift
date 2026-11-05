import Testing
@testable import OpenSesameCore

@Test func closeAndWindowChromeNeverReceiveHints() {
    for subrole in ["AXCloseButton", "AXMinimizeButton", "AXZoomButton", "AXFullScreenButton"] {
        #expect(TargetExclusion.excludes(role: "AXButton", subrole: subrole, title: "", description: "", kind: .control))
    }
    for title in ["Close", "Close Tab", "Close Window", "Quit Ghostty", "Force Quit…", "Minimize", "Zoom", "Enter Full Screen"] {
        #expect(TargetExclusion.excludes(role: "AXMenuItem", subrole: "", title: title, description: "", kind: .menu))
    }
    #expect(TargetExclusion.excludes(role: "AXButton", subrole: "", title: "", description: "close tab", kind: .close))
}
@Test func navigationAndUnrelatedNamedControlsAreKept() {
    for title in ["System Settings…", "About This Mac", "Open", "Closure settings", "Zoom meeting"] {
        #expect(!TargetExclusion.excludes(role: "AXPopUpButton", subrole: "", title: title, description: "", kind: .control))
    }
    #expect(!TargetExclusion.excludes(role: "AXRadioButton", subrole: "", title: "Shell", description: "", kind: .tab))
    #expect(!TargetExclusion.excludes(role: "AXButton", subrole: "", title: "Open", description: "", kind: .control))
    #expect(!TargetExclusion.excludes(role: "AXButton", subrole: "", title: "Zoom meeting", description: "", kind: .control))
}

@Test func actionWordsInTabTitlesRemainSelectable() {
    for title in ["Zoom", "Close", "Close project", "Minimize"] {
        let kind = TargetKind.classify(role: "AXRadioButton", subrole: "", parentRole: "AXTabGroup", description: title)
        #expect(kind == .tab)
        #expect(!TargetExclusion.excludes(role: "AXRadioButton", subrole: "", title: title, description: "", kind: kind))
    }
}

@Test func ghosttyUpdateBannerIsExcludedWithoutHidingOtherAppUpdates() {
    #expect(TargetExclusion.excludes(role: "AXButton", subrole: "", title: "", description: "Update Available: e95bed633 (2026-11-04)", kind: .control, bundleID: "com.mitchellh.ghostty"))
    #expect(!TargetExclusion.excludes(role: "AXButton", subrole: "", title: "", description: "Update Available: e95bed633", kind: .control, bundleID: "com.example.editor"))
    #expect(!TargetExclusion.excludes(role: "AXMenuItem", subrole: "", title: "Check for Updates…", description: "", kind: .menu, bundleID: "com.mitchellh.ghostty"))
    #expect(!TargetExclusion.excludes(role: "AXRadioButton", subrole: "AXTabButton", title: "Update Available: project", description: "", kind: .tab, bundleID: "com.mitchellh.ghostty"))
}

@Test func windowChromeRolesAreExcludedEvenWhenSubrolesAreMissing() {
    for role in ["AXCloseButton", "AXMinimizeButton", "AXZoomButton", "AXFullScreenButton", "AXGrowArea"] {
        #expect(TargetExclusion.excludes(role: role, subrole: "", title: "", description: "", kind: .control))
    }
}
