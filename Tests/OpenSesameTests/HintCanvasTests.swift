import AppKit
import ApplicationServices
import Testing
import OpenSesameCore
@testable import OpenSesame

@MainActor
struct HintCanvasTests {
    private func canvas() -> HintCanvas {
        _ = NSApplication.shared
        let view = HintCanvas(frame: CGRect(x: 0, y: 0, width: 1000, height: 600))
        view.screenFrame = view.bounds; view.desktopTop = view.bounds.height
        return view
    }
    private func target(_ code: String, _ frame: CGRect, kind: TargetKind = .control, role: String = "AXButton", title: String = "") -> Target {
        Target(element: AXUIElementCreateApplication(0), frame: frame, label: code, kind: kind,
               action: "AXPress", clicksMenuBarExtra: false,
               metadata: TargetMetadata(role: role, subrole: "", title: title, description: "", owner: 0, bundleID: "preview"))
    }
    private func render(_ canvas: HintCanvas) throws {
        let bitmap = try #require(canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds))
        canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
    }
    @Test func menuBarNamesDoNotChangeTargetOutlinePolicy() throws {
        let view = canvas()
        view.targets = [
            target("aa", CGRect(x: 80, y: 4, width: 24, height: 24), kind: .menu, role: "AXMenuBarItem"),
            target("ab", CGRect(x: 150, y: 4, width: 24, height: 24), kind: .menu, role: "AXMenuBarItem", title: "Wi-Fi"),
            target("ac", CGRect(x: 300, y: 200, width: 24, height: 24))
        ]
        try render(view)
        #expect(view.drawnLabels == ["aa", "ab", "ac"])
        #expect(view.associatedLabels == ["ac"])
        let frames = view.localBadgeFrames
        view.prefix = "aa"
        try render(view)
        #expect(view.drawnLabels == ["aa"] && view.associatedLabels.isEmpty)
        #expect(view.localBadgeFrames == frames.filter { $0.key == "aa" })
    }
    @Test func desktopOverflowUsesItsOwnPageAndNeverEntersTheAppList() throws {
        let view = canvas()
        view.appName = "Browser"
        view.targets = [
            target("aa", CGRect(x: 200, y: 200, width: 8, height: 8), kind: .tab, role: "AXTab", title: "Page"),
            target("dd", CGRect(x: 900, y: 380, width: 8, height: 8), kind: .desktop, role: "AXImage", title: "Screenshot.png")
        ]
        try render(view)
        #expect(view.ledgerHeading == "Browser · More controls")
        #expect(view.ledgerCaptions == ["aa": "Page"])
        #expect(view.ledgerPageCount == 2)
        view.ledgerPage = 1
        try render(view)
        #expect(view.ledgerHeading == "Desktop · More controls")
        #expect(view.ledgerCaptions == ["dd": "Screenshot.png"])
        let panel = view.ledgerPanelFrame
        view.prefix = "d"
        try render(view)
        #expect(view.ledgerHeading == "Desktop · More controls")
        #expect(view.ledgerPanelFrame == panel)
        #expect(view.ledgerCaptions == ["dd": "Screenshot.png"])
    }
    @Test func mixedOverflowKeepsMembershipAndHidesWhenOnlyLocalHintsMatch() throws {
        let view = canvas()
        view.targets = [target("ss", CGRect(x: 40, y: 0, width: 30, height: 24), kind: .menu, role: "AXMenuBarItem", title: "App"),
                        target("aa", CGRect(x: 300, y: 70, width: 180, height: 28), kind: .tab, role: "AXTab", title: "Tab"),
                        target("dd", CGRect(x: 900, y: 380, width: 8, height: 8), kind: .window, role: "AXWindow", title: "Window")]
        try render(view)
        let local = view.localBadgeFrames
        let panel = try #require(view.ledgerPanelFrame)
        #expect(view.overflowLabels == ["dd"])
        for prefix in ["a", "d", "s", "z", ""] {
            view.prefix = prefix
            try render(view)
            #expect(view.overflowLabels == ["dd"])
            #expect(view.localBadgeFrames == local.filter { $0.key.hasPrefix(prefix) })
            #expect(view.drawnLabels == Set(view.targets.filter { $0.label.hasPrefix(prefix) }.map(\.label)))
            #expect(view.usesLedger == "dd".hasPrefix(prefix))
            #expect(view.ledgerPanelFrame == ("dd".hasPrefix(prefix) ? panel : nil))
        }
    }
    @Test func unnamedExteriorRowKeepsLeadersAndTargetOutlinesWhileFiltering() throws {
        let view = canvas()
        view.scopeFrame = CGRect(x: 180, y: 180, width: 200, height: 200)
        view.textFrames = [CGRect(x: 180, y: 200, width: 200, height: 34), CGRect(x: 180, y: 270, width: 200, height: 34)]
        view.targets = [target("aa", CGRect(x: 220, y: 240, width: 24, height: 24)),
                        target("bb", CGRect(x: 260, y: 240, width: 24, height: 24))]
        try render(view)
        let frames = view.localBadgeFrames
        #expect(view.associatedLabels == view.localLabels)
        #expect(view.drawnLabels == ["aa", "bb"])
        view.prefix = "b"
        try render(view)
        #expect(view.associatedLabels == view.localLabels)
        #expect(view.drawnLabels == ["bb"])
        #expect(view.localBadgeFrames == frames.filter { $0.key == "bb" })
    }

    @Test func regionCodesStayCenteredAndKeepMatchingColorsInOverflowAndFiltering() throws {
        let view = canvas()
        view.targets = (0..<4).map { index in
            target(["aa", "ab", "ba", "bb"][index], CGRect(x: 80 + index % 2 * 450, y: 100 + index / 2 * 240, width: 300, height: 140),
                   role: "OpenSesameSection", title: "Region \(index + 1)")
        }
        // Text and controls may fill a pane. The region code deliberately
        // overlays its center rather than searching for an exterior caption.
        view.textFrames = view.targets.flatMap { target in
            [CGRect(x: target.frame.minX - 10, y: target.frame.minY - 50, width: 320, height: 44),
             CGRect(x: target.frame.minX - 10, y: target.frame.maxY + 2, width: 320, height: 44)]
        }
        for index in view.targets.indices {
            let frame = view.targets[index].frame
            view.targets[index].sectionMemberFrames = [CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: 32)]
        }
        for dark in [false, true] {
            view.palette = ThemePalette(theme: .glitch, dark: dark)
            view.prefix = ""
            try render(view)
            let colors = view.drawnAccents
            let local = view.localBadgeFrames
            #expect(colors == view.sectionOutlineAccents)
            #expect(Set(colors.values).count == 4)
            #expect(local.count == 4)
            #expect(view.regionMarkerFrames == local)
            for target in view.targets {
                let marker = try #require(local[target.label])
                #expect(marker.midX == target.frame.midX)
                #expect(marker.midY == view.desktopTop - target.frame.midY)
                #expect(marker.height >= 48)
            }
            view.prefix = "b"
            try render(view)
            #expect(view.drawnAccents == colors.filter { $0.key.hasPrefix("b") })
            #expect(view.sectionOutlineAccents == view.drawnAccents)
            #expect(view.localBadgeFrames == local.filter { $0.key.hasPrefix("b") })
            // The same section colors must follow choices into the action panel.
            view.prefix = ""
            view.prefersActionPanel = true
            try render(view)
            #expect(view.usesLedger)
            #expect(view.localBadgeFrames.isEmpty)
            #expect(view.drawnAccents == colors)
            view.prefix = "b"
            try render(view)
            #expect(view.drawnAccents == colors.filter { $0.key.hasPrefix("b") })
            view.prefersActionPanel = false
        }
    }

    @Test func inseparableClusterUsesOnePagedPanelAndPreservesEveryAction() throws {
        let view = canvas()
        view.prefersActionPanel = true
        let labels = Hints.labels(count: 70)
        view.targets = labels.map { target($0, CGRect(x: 60, y: 60, width: 400, height: 300), title: "Action") }
        var reached = Set<String>()
        for page in 0..<labels.count {
            view.ledgerPage = page
            try render(view)
            #expect(view.localBadgeFrames.isEmpty)
            #expect(view.usesLedger)
            reached.formUnion(view.drawnLabels)
            if reached == Set(labels) { break }
        }
        #expect(reached == Set(labels))
        view.prefix = labels.last!
        try render(view)
        #expect(view.drawnLabels == [labels.last!])
    }

    @Test func crowdedControlPanelKeepsWindowCodesInsideTheirWindows() throws {
        let view = canvas()
        view.prefersActionPanel = true
        view.scopeFrame = CGRect(x: 50, y: 80, width: 400, height: 440)
        let labels = Hints.labels(count: 50)
        view.targets = [target("zz", CGRect(x: 650, y: 80, width: 300, height: 440), kind: .window, role: "AXWindow", title: "Other window")]
            + labels.map { target($0, CGRect(x: 80, y: 100, width: 320, height: 380), title: "Action") }
        try render(view)
        let marker = try #require(view.regionMarkerFrames["zz"])
        #expect(marker.midX == 800 && marker.midY == 300)
        #expect(view.usesLedger)
        #expect(!view.overflowLabels.contains("zz"))
        view.prefix = "zz"
        try render(view)
        #expect(view.regionMarkerFrames == ["zz": marker])
        #expect(view.drawnLabels == ["zz"])
        #expect(!view.usesLedger)
    }

    @Test func crowdedControlPanelKeepsFittingTabsInlineAndNarrowTabsReachable() throws {
        let view = canvas()
        view.prefersActionPanel = true
        view.scopeFrame = CGRect(x: 50, y: 100, width: 800, height: 400)
        let labels = Hints.labels(count: 50)
        view.targets = [target("zx", CGRect(x: 60, y: 40, width: 180, height: 40), kind: .tab, role: "AXTab", title: "Wide tab"),
                        target("zy", CGRect(x: 260, y: 40, width: 24, height: 40), kind: .tab, role: "AXTab", title: "Narrow tab")]
            + labels.map { target($0, CGRect(x: 80, y: 140, width: 700, height: 300), title: "Action") }
        try render(view)
        let inline = try #require(view.localBadgeFrames["zx"])
        #expect(CGRect(x: 60, y: 520, width: 180, height: 40).contains(inline))
        #expect(view.overflowLabels.contains("zy"))
        view.prefix = "zy"
        try render(view)
        #expect(view.drawnLabels == ["zy"] && view.usesLedger)
        view.prefix = "zx"
        try render(view)
        #expect(view.localBadgeFrames == ["zx": inline] && !view.usesLedger)
    }
}

@MainActor
@Test func unnamedIndividualExteriorHintKeepsItsTargetAssociation() throws {
    _ = NSApplication.shared
    let view = HintCanvas(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
    view.screenFrame = view.bounds; view.desktopTop = view.bounds.height
    view.scopeFrame = CGRect(x: 180, y: 180, width: 200, height: 200)
    view.textFrames = [CGRect(x: 180, y: 200, width: 200, height: 34),
                       CGRect(x: 180, y: 310, width: 200, height: 35),
                       CGRect(x: 185, y: 240, width: 30, height: 64)]
    view.targets = [Target(element: AXUIElementCreateApplication(0), frame: CGRect(x: 220, y: 240, width: 100, height: 64),
        label: "aa", kind: .control, action: "AXPress", clicksMenuBarExtra: false,
        metadata: TargetMetadata(role: "AXButton", subrole: "", title: "", description: "", owner: 0, bundleID: "preview"))]
    let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
    view.cacheDisplay(in: view.bounds, to: bitmap)
    #expect(view.associatedLabels == view.localLabels)
    #expect(view.drawnLabels == ["aa"])
    #expect(view.usesLedger || view.localLabels == ["aa"])
}

@MainActor
@Test func overflowPagesKeepEachOwnerSeparateAndPreferTheActiveApp() throws {
    _ = NSApplication.shared
    let view = HintCanvas(frame: CGRect(x: 0, y: 0, width: 1000, height: 600))
    view.screenFrame = view.bounds; view.desktopTop = 600; view.owner = 42
    view.windowFrame = CGRect(x: 300, y: 80, width: 400, height: 440)
    view.targets = [("aa", Int32(41)), ("dd", Int32(42)), ("ff", Int32(43))].map { code, pid in
        Target(element: AXUIElementCreateApplication(0), frame: CGRect(x: 350, y: 100, width: 8, height: 8),
            label: code, kind: .tab, action: "AXPress", clicksMenuBarExtra: false,
            metadata: .init(role: "AXRadioButton", subrole: "", title: "A readable website title", description: "Browser · structural description", owner: pid, bundleID: "preview"))
    }
    var reached = Set<String>(), frames: [String: CGRect] = [:]
    for page in 0..<3 {
        view.ledgerPage = page
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        #expect(view.ledgerPageCount == 3)
        #expect(view.ledgerCaptions.count == 1)
        #expect(Set(view.ledgerCaptions.values) == ["A readable website title"])
        if page == 0 { #expect(view.drawnLabels == ["dd"]) }
        reached.formUnion(view.drawnLabels)
        for label in view.drawnLabels { frames[label] = view.ledgerPanelFrame }
    }
    #expect(reached == ["aa", "dd", "ff"])
    for label in reached {
        view.prefix = label
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        #expect(view.drawnLabels == [label])
        #expect(view.ledgerPanelFrame == frames[label])
    }
}
