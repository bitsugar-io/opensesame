#if DEBUG
import AppKit
import ApplicationServices
import OpenSesameCore

/// Captured browser geometry with all titles and user content removed. The same
/// discovery policy must work for every provider, not a browser-specific layout.
enum ContainerSelectionPreview {
    private static let items: [(String, TargetKind, String, CGFloat, CGFloat, CGFloat, CGFloat)] = [
        ("AXGroup", .control, "AXShowMenu", 0, 0, 2725, 1268),
        ("AXTabGroup", .tab, "AXShowMenu", 114, 0, 70, 41),
        ("AXRadioButton", .tab, "AXPress", 166, 0, 46, 41),
        ("AXTabGroup", .tab, "AXShowMenu", 194, 0, 92, 41),
        ("AXTabGroup", .tab, "AXShowMenu", 268, 0, 116, 41),
        ("AXTabGroup", .tab, "AXShowMenu", 366, 0, 145, 41),
        ("AXTabGroup", .tab, "AXShowMenu", 493, 0, 98, 41),
        ("AXTabGroup", .tab, "AXShowMenu", 573, 0, 129, 41),
        ("AXTabGroup", .tab, "AXShowMenu", 684, 0, 93, 41),
        ("AXTabGroup", .tab, "AXShowMenu", 759, 0, 86, 41),
        ("AXTabGroup", .tab, "AXShowMenu", 827, 0, 126, 41),
        ("AXTabGroup", .tab, "AXShowMenu", 935, 0, 76, 41),
        ("AXTabGroup", .tab, "AXShowMenu", 993, 0, 113, 41),
        ("AXTabGroup", .tab, "AXShowMenu", 1088, 0, 114, 41),
        ("AXTabGroup", .tab, "AXShowMenu", 1184, 0, 84, 41),
        ("AXTabGroup", .tab, "AXShowMenu", 1250, 0, 122, 41),
        ("AXTabGroup", .tab, "AXShowMenu", 1354, 0, 67, 41),
        ("AXTabGroup", .tab, "AXShowMenu", 1403, 0, 126, 41),
        ("AXTabGroup", .tab, "AXShowMenu", 1511, 0, 157, 41),
        ("AXTabGroup", .tab, "AXShowMenu", 1650, 0, 143, 41),
        ("AXTabGroup", .tab, "AXShowMenu", 1775, 0, 92, 41),
        ("AXTabGroup", .tab, "AXShowMenu", 1849, 0, 84, 41),
        ("AXTabGroup", .tab, "AXShowMenu", 1915, 0, 75, 41),
        ("AXTabGroup", .tab, "AXShowMenu", 1972, 0, 66, 41),
        ("AXTabGroup", .tab, "AXShowMenu", 2020, 0, 123, 41),
        ("AXRadioButton", .tab, "AXPress", 2125, 0, 46, 41),
        ("AXRadioButton", .tab, "AXPress", 2153, 0, 46, 41),
        ("AXRadioButton", .tab, "AXPress", 2181, 0, 46, 41),
        ("AXRadioButton", .tab, "AXPress", 2209, 0, 46, 41),
        ("AXRadioButton", .tab, "AXPress", 2237, 0, 46, 41),
        ("AXRadioButton", .tab, "AXPress", 2265, 0, 46, 41),
        ("AXRadioButton", .tab, "AXPress", 2293, 0, 46, 41),
        ("AXRadioButton", .tab, "AXPress", 2321, 0, 46, 41),
        ("AXRadioButton", .tab, "AXPress", 2349, 0, 46, 41),
        ("AXRadioButton", .tab, "AXPress", 2377, 0, 45, 41),
        ("AXRadioButton", .tab, "AXPress", 2404, 0, 45, 41),
        ("AXRadioButton", .tab, "AXPress", 2431, 0, 45, 41),
        ("AXRadioButton", .tab, "AXPress", 2458, 0, 45, 41),
        ("AXRadioButton", .tab, "AXPress", 2485, 0, 45, 41),
        ("AXRadioButton", .tab, "AXPress", 2512, 0, 45, 41),
        ("AXRadioButton", .tab, "AXPress", 2539, 0, 45, 41),
        ("AXRadioButton", .tab, "AXPress", 2566, 0, 45, 41),
        ("AXRadioButton", .tab, "AXPress", 2593, 0, 56, 41),
        ("AXButton", .control, "AXPress", 2643, 0, 28, 41),
        ("AXPopUpButton", .menu, "AXPress", 92, 6, 28, 28),
        ("AXButton", .control, "AXPress", 6, 46, 34, 34),
        ("AXButton", .control, "AXPress", 78, 46, 34, 34),
        ("AXGroup", .control, "AXShowMenu", 121, 46, 2200, 34),
        ("AXPopUpButton", .menu, "AXPress", 2330, 46, 34, 34),
        ("AXPopUpButton", .menu, "AXPress", 2366, 46, 34, 34),
        ("AXPopUpButton", .menu, "AXPress", 2402, 46, 34, 34),
        ("AXPopUpButton", .menu, "AXPress", 2438, 46, 34, 34),
        ("AXPopUpButton", .menu, "AXPress", 2474, 46, 34, 34),
        ("AXPopUpButton", .menu, "AXPress", 2510, 46, 34, 34),
        ("AXPopUpButton", .menu, "AXPress", 2546, 46, 34, 34),
        ("AXButton", .control, "AXPress", 2600, 46, 80, 34),
        ("AXPopUpButton", .menu, "AXPress", 2685, 46, 34, 34),
        ("AXPopUpButton", .menu, "AXPress", 126, 51, 24, 24),
        ("AXTextField", .control, "AXPress", 158, 51, 2055, 24),
        ("AXButton", .control, "AXPress", 2221, 51, 24, 24),
        ("AXButton", .control, "AXPress", 2253, 51, 24, 24),
        ("AXButton", .control, "AXPress", 2285, 51, 24, 24),
        ("AXLink", .control, "AXShowMenu", 16, 103, 64, 64),
        ("AXButton", .control, "AXShowMenu", 910, 103, 913, 64),
        ("AXLink", .control, "AXShowMenu", 2319, 103, 104, 64),
        ("AXLink", .control, "AXShowMenu", 2422, 103, 104, 64),
        ("AXLink", .control, "AXShowMenu", 2525, 103, 104, 64),
        ("AXLink", .control, "AXShowMenu", 2645, 103, 64, 64),
        ("AXLink", .control, "AXShowMenu", 24, 111, 50, 48),
        ("AXLink", .control, "AXShowMenu", 2155, 111, 49, 48),
        ("AXButton", .control, "AXShowMenu", 2219, 111, 49, 48),
        ("AXButton", .control, "AXShowMenu", 506, 185, 176, 13),
        ("AXButton", .control, "AXShowMenu", 689, 185, 87, 13),
        ("AXButton", .control, "AXShowMenu", 783, 185, 190, 13),
        ("AXButton", .control, "AXShowMenu", 988, 185, 127, 12),
        ("AXButton", .control, "AXShowMenu", 2059, 193, 369, 64),
        ("AXButton", .control, "AXShowMenu", 2443, 193, 122, 64),
        ("AXPopUpButton", .menu, "AXShowMenu", 2661, 199, 48, 48),
        ("AXButton", .control, "AXShowMenu", 2581, 201, 48, 48),
        ("AXLink", .control, "AXShowMenu", 506, 208, 144, 34),
        ("AXLink", .control, "AXShowMenu", 690, 208, 136, 34),
        ("AXLink", .control, "AXShowMenu", 866, 208, 191, 34),
        ("AXLink", .control, "AXShowMenu", 1097, 208, 96, 34),
        ("AXLink", .control, "AXShowMenu", 1232, 208, 105, 34),
        ("AXLink", .control, "AXShowMenu", 1376, 208, 171, 34),
        ("AXRadioButton", .tab, "AXShowMenu", 506, 257, 162, 89),
        ("AXRadioButton", .tab, "AXShowMenu", 667, 257, 169, 89),
        ("AXRadioButton", .tab, "AXShowMenu", 835, 257, 253, 89),
        ("AXRadioButton", .tab, "AXShowMenu", 1087, 257, 213, 89),
        ("AXLink", .control, "AXShowMenu", 16, 269, 433, 56),
        ("AXRadioButton", .tab, "AXShowMenu", 2657, 285, 56, 56),
        ("AXButton", .control, "AXShowMenu", 16, 341, 433, 56),
        ("AXRadioButton", .tab, "AXShowMenu", 2657, 357, 56, 56),
        ("AXButton", .control, "AXShowMenu", 718, 388, 127, 64),
        ("AXButton", .control, "AXShowMenu", 846, 388, 296, 64),
        ("AXLink", .control, "AXShowMenu", 16, 401, 433, 56),
        ("AXButton", .control, "AXShowMenu", 385, 405, 48, 48),
        ("AXRadioButton", .tab, "AXShowMenu", 2657, 429, 56, 56),
        ("AXLink", .control, "AXShowMenu", 16, 461, 433, 56),
        ("AXButton", .control, "AXShowMenu", 385, 465, 48, 48),
        ("AXLink", .control, "AXShowMenu", 16, 521, 433, 56),
        ("AXButton", .control, "AXShowMenu", 385, 525, 48, 48),
        ("AXButton", .control, "AXShowMenu", 532, 566, 64, 154),
        ("AXLink", .control, "AXShowMenu", 16, 581, 433, 56),
        ("AXButton", .control, "AXShowMenu", 385, 585, 48, 48),
        ("AXLink", .control, "AXShowMenu", 678, 617, 158, 29),
        ("AXButton", .control, "AXShowMenu", 16, 641, 433, 56),
        ("AXLink", .control, "AXShowMenu", 1138, 654, 698, 80),
        ("AXButton", .control, "AXShowMenu", 1773, 670, 49, 48),
        ("AXLink", .control, "AXShowMenu", 1138, 742, 698, 80),
        ("AXButton", .control, "AXShowMenu", 16, 747, 433, 56),
        ("AXButton", .control, "AXShowMenu", 1773, 758, 49, 48),
        ("AXButton", .control, "AXShowMenu", 16, 807, 433, 56),
        ("AXButton", .control, "AXShowMenu", 1138, 840, 698, 80),
        ("AXButton", .control, "AXShowMenu", 16, 867, 433, 56),
        ("AXButton", .control, "AXShowMenu", 16, 927, 433, 56),
        ("AXLink", .control, "AXShowMenu", 1138, 928, 698, 80),
        ("AXButton", .control, "AXShowMenu", 1773, 944, 49, 48),
        ("AXButton", .control, "AXShowMenu", 16, 987, 433, 56),
        ("AXButton", .control, "AXShowMenu", 1138, 1016, 698, 80),
        ("AXLink", .control, "AXShowMenu", 16, 1047, 433, 53),
        ("AXButton", .control, "AXShowMenu", 385, 1051, 48, 48),
        ("AXButton", .control, "AXShowMenu", 16, 1116, 448, 56),
        ("AXButton", .control, "AXShowMenu", 16, 1180, 448, 56),
        ("AXLink", .control, "AXShowMenu", 2657, 1180, 56, 56),
        ("AXLink", .control, "AXShowMenu", 1203, 1223, 154, 32),
        ("AXLink", .control, "AXShowMenu", 1388, 1223, 174, 32),
        ("AXCheckBox", .control, "AXShowMenu", 2537, 1223, 172, 32),
    ]
    static func render(to directory: URL) throws {
        for dark in [true, false] {
            let palette = ThemePalette(theme: .glitch, dark: dark)
            var reference: [CGRect]?
            for provider in ["com.google.Chrome", "test.native"] {
                let all = items.enumerated().map { index, item in
                    Target(element: AXUIElementCreateApplication(0), frame: CGRect(x: 24 + item.3, y: 48 + item.4, width: item.5, height: item.6),
                        label: "unused", kind: item.1, action: item.2, clicksMenuBarExtra: false,
                        metadata: TargetMetadata(role: item.0, subrole: "", title: "Action \(index)", description: "", owner: 0, bundleID: provider))
                }
                let filtered = all.filter { !TargetExclusion.excludes(role: $0.metadata.role, subrole: "", title: $0.metadata.title,
                    description: "", kind: $0.kind, bundleID: provider, action: $0.action) }
                var navigation = SectionNavigation()
                let root = navigation.reset(filtered, scopedPopup: false, configuration: .standard, windowFrame: CGRect(x: 24, y: 48, width: 2725, height: 1268))
                guard filtered.count == 126, navigation.sectionCount == 3,
                      root.flatMap(\.sectionMemberFrames).count == filtered.filter({ $0.kind != .tab }).count,
                      root.filter({ $0.kind == .tab }).count == 49,
                      reference == nil || reference == root.map(\.frame) else { throw CocoaError(.coderInvalidValue) }
                reference = root.map(\.frame)
                let view = NSView(frame: CGRect(x: 0, y: 0, width: 2773, height: 1360))
                view.wantsLayer = true; view.layer?.backgroundColor = NSColor(rgb: palette.background).cgColor
                let canvas = HintCanvas(frame: view.bounds)
                canvas.palette = palette; canvas.screenFrame = view.bounds; canvas.desktopTop = view.bounds.height
                canvas.windowFrame = CGRect(x: 24, y: 48, width: 2725, height: 1268)
                canvas.appName = "Example app"
                canvas.appIcon = AppIdentity.icon(bundleID: "preview")
                view.addSubview(canvas)
                guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw CocoaError(.coderInvalidValue) }
                guard let toolbarControl = filtered.first(where: { $0.kind == .control }) else { throw CocoaError(.coderInvalidValue) }
                for level in 0..<8 {
                    canvas.targets = navigation.targets
                    canvas.scopeFrame = navigation.scopeFrame
                    canvas.prefersActionPanel = navigation.prefersActionPanel
                    canvas.canGoBack = navigation.depth > 0
                    let tabs = navigation.targets.filter { $0.kind == .tab }
                    guard tabs.count == (navigation.depth == 0 ? 49 : 0) else { throw CocoaError(.coderInvalidValue) }
                    var reached = Set<String>()
                    for page in 0..<navigation.targets.count {
                        canvas.ledgerPage = page
                        view.cacheDisplay(in: view.bounds, to: bitmap)
                        reached.formUnion(canvas.drawnLabels)
                        if reached == Set(navigation.targets.map(\.label)) { break }
                    }
                    guard reached == Set(navigation.targets.map(\.label)) else { throw CocoaError(.coderInvalidValue) }
                    canvas.ledgerPage = 0
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    // Every fitting tab stays within its own rectangle. Narrow
                    // tabs remain named, reachable choices in the overflow panel.
                    for tab in tabs {
                        if let badge = canvas.localBadgeFrames[tab.label] {
                            let rect = CGRect(x: tab.frame.minX, y: view.bounds.height - tab.frame.maxY, width: tab.frame.width, height: tab.frame.height)
                            guard rect.contains(badge) else { throw CocoaError(.coderInvalidValue) }
                        } else if !canvas.overflowLabels.contains(tab.label) { throw CocoaError(.coderInvalidValue) }
                    }
                    let suffix = level == 0 ? "sections" : "level\(level + 1)"
                    try bitmap.representation(using: .png, properties: [:])!.write(to:
                        directory.appendingPathComponent("layout-container-\(suffix)-\(dark ? "dark" : "light").png"))
                    guard let section = navigation.targets.first(where: { $0.sectionMemberFrames.contains(toolbarControl.frame) }) else { break }
                    guard navigation.select(section.label, configuration: .standard), level < 7 else { throw CocoaError(.coderInvalidValue) }
                }
            }
        }
    }
}
#endif
