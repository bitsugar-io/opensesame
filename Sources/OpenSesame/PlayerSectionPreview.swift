#if DEBUG
import AppKit
import ApplicationServices
import OpenSesameCore

/// Geometry and roles from a 73-control Spotify scan, with all private content
/// removed. Synthetic controls exercise the real navigation and hint canvas;
/// this fixture never contacts Spotify or changes playback.
final class PlayerSectionPreview: NSView {
    private static let items: [(String, TargetKind, String, CGFloat, CGFloat, CGFloat, CGFloat)] = [
        ("AXButton", .control, "", 96, 8, 24, 48),
        ("AXButton", .control, "", 500, 8, 48, 48),
        ("AXButton", .control, "", 556, 8, 48, 48),
        ("AXComboBox", .control, "", 556, 8, 474, 48),
        ("AXButton", .control, "", 1474, 8, 48, 48),
        ("AXButton", .control, "", 1394, 16, 32, 32),
        ("AXButton", .control, "", 1434, 16, 32, 32),
        ("AXButton", .control, "", 990, 20, 24, 25),
        ("AXButton", .control, "", 269, 80, 100, 36),
        ("AXButton", .control, "", 377, 80, 35, 36),
        ("AXButton", .control, "", 1118, 80, 16, 32),
        ("AXPopUpButton", .menu, "", 1442, 80, 32, 32),
        ("AXButton", .control, "", 1474, 80, 32, 32),
        ("AXButton", .control, "", 8, 83, 111, 30),
        ("AXButton", .control, "", 453, 111, 143, 143),
        ("AXMenuItem", .menu, "", 24, 132, 32, 32),
        ("AXMenuItem", .menu, "", 64, 132, 82, 32),
        ("AXButton", .control, "", 24, 174, 32, 32),
        ("AXComboBox", .control, "", 329, 174, 75, 32),
        ("AXButton", .control, "", 16, 214, 404, 64),
        ("AXButton", .control, "", 24, 222, 48, 48),
        ("AXLink", .control, "", 612, 224, 465, 30),
        ("AXButton", .control, "", 16, 278, 404, 64),
        ("AXButton", .control, "", 24, 286, 48, 48),
        ("AXButton", .control, "", 453, 318, 57, 57),
        ("AXButton", .control, "", 526, 318, 33, 57),
        ("AXButton", .control, "", 575, 318, 33, 57),
        ("AXPopUpButton", .menu, "", 624, 318, 33, 57),
        ("AXButton", .control, "", 16, 342, 404, 64),
        ("AXButton", .control, "", 24, 350, 48, 48),
        ("AXRadioButton", .tab, "", 441, 391, 111, 49),
        ("AXRadioButton", .tab, "", 551, 391, 99, 49),
        ("AXRadioButton", .tab, "", 649, 391, 93, 49),
        ("AXButton", .control, "", 16, 406, 404, 64),
        ("AXButton", .control, "", 24, 414, 48, 48),
        ("AXButton", .control, "", 16, 470, 404, 64),
        ("AXButton", .control, "", 24, 478, 48, 48),
        ("AXLink", .control, "", 1118, 532, 201, 29),
        ("AXCheckBox", .control, "", 1446, 533, 24, 49),
        ("AXButton", .control, "", 1482, 533, 24, 49),
        ("AXButton", .control, "", 16, 534, 404, 64),
        ("AXButton", .control, "", 24, 542, 48, 48),
        ("AXButton", .control, "", 1410, 545, 24, 25),
        ("AXButton", .control, "", 453, 559, 98, 23),
        ("AXLink", .control, "", 1118, 561, 91, 22),
        ("AXButton", .control, "", 16, 598, 404, 64),
        ("AXButton", .control, "", 24, 606, 48, 48),
        ("AXLink", .control, "", 453, 625, 138, 33),
        ("AXButton", .control, "", 16, 662, 404, 64),
        ("AXButton", .control, "", 24, 670, 48, 48),
        ("AXButton", .control, "", 16, 726, 404, 64),
        ("AXButton", .control, "", 24, 734, 48, 48),
        ("AXTextArea", .control, "", 497, 742, 557, 57),
        ("AXButton", .control, "", 1384, 765, 106, 23),
        ("AXButton", .control, "", 16, 790, 404, 48),
        ("AXButton", .control, "", 24, 798, 48, 40),
        ("AXLink", .control, "", 556, 812, 93, 21),
        ("AXButton", .control, "", 1110, 834, 210, 4),
        ("AXButton", .control, "", 1320, 834, 186, 4),
        ("AXButton", .control, "", 701, 853, 32, 33),
        ("AXButton", .control, "Play", 749, 853, 32, 33),
        ("AXButton", .control, "", 797, 853, 32, 33),
        ("AXButton", .control, "", 16, 854, 56, 56),
        ("AXLink", .control, "", 88, 863, 120, 21),
        ("AXCheckBox", .control, "", 229, 866, 17, 32),
        ("AXButton", .control, "", 257, 866, 17, 32),
        ("AXCheckBox", .control, "", 1229, 866, 32, 32),
        ("AXCheckBox", .control, "", 1261, 866, 32, 32),
        ("AXCheckBox", .control, "", 1293, 866, 32, 32),
        ("AXButton", .control, "", 1325, 866, 32, 32),
        ("AXCheckBox", .control, "", 1458, 866, 32, 32),
        ("AXCheckBox", .control, "", 1490, 866, 32, 32),
        ("AXLink", .control, "", 88, 883, 78, 18)
    ]
    // Second capture: home screen geometry, with all content names removed.
    private static let homeItems: [(String, TargetKind, String, CGFloat, CGFloat, CGFloat, CGFloat)] = [
        ("AXButton", .control, "", 96, 8, 24, 48),
        ("AXButton", .control, "", 500, 8, 48, 48),
        ("AXButton", .control, "", 556, 8, 48, 48),
        ("AXComboBox", .control, "", 556, 8, 474, 48),
        ("AXButton", .control, "", 1474, 8, 48, 48),
        ("AXButton", .control, "", 1394, 16, 32, 32),
        ("AXButton", .control, "", 1434, 16, 32, 32),
        ("AXButton", .control, "", 990, 20, 24, 25),
        ("AXButton", .control, "", 269, 80, 100, 36),
        ("AXButton", .control, "", 377, 80, 35, 36),
        ("AXButton", .control, "", 1102, 80, 16, 32),
        ("AXPopUpButton", .menu, "", 1442, 80, 32, 32),
        ("AXButton", .control, "", 1474, 80, 32, 32),
        ("AXButton", .control, "", 8, 83, 111, 30),
        ("AXCheckBox", .control, "", 476, 84, 41, 32),
        ("AXCheckBox", .control, "", 524, 84, 62, 32),
        ("AXCheckBox", .control, "", 593, 84, 82, 32),
        ("AXCheckBox", .control, "", 682, 84, 103, 32),
        ("AXMenuItem", .menu, "", 24, 132, 32, 32),
        ("AXMenuItem", .menu, "", 64, 132, 82, 32),
        ("AXLink", .control, "", 825, 136, 221, 40),
        ("AXLink", .control, "", 532, 137, 155, 20),
        ("AXButton", .control, "", 721, 140, 32, 32),
        ("AXButton", .control, "", 1014, 140, 32, 32),
        ("AXButton", .control, "", 24, 172, 32, 18),
        ("AXComboBox", .control, "", 329, 172, 75, 18),
        ("AXButton", .control, "", 721, 196, 32, 32),
        ("AXButton", .control, "", 1014, 196, 32, 32),
        ("AXButton", .control, "", 16, 198, 404, 64),
        ("AXLink", .control, "", 532, 202, 177, 20),
        ("AXLink", .control, "", 825, 202, 192, 20),
        ("AXButton", .control, "", 24, 206, 48, 48),
        ("AXButton", .control, "", 721, 252, 32, 32),
        ("AXButton", .control, "", 1014, 252, 32, 32),
        ("AXLink", .control, "", 532, 258, 68, 20),
        ("AXLink", .control, "", 825, 258, 159, 20),
        ("AXButton", .control, "", 16, 262, 404, 64),
        ("AXButton", .control, "", 24, 270, 48, 48),
        ("AXButton", .control, "", 721, 308, 32, 32),
        ("AXButton", .control, "", 1014, 308, 32, 32),
        ("AXLink", .control, "", 532, 312, 158, 24),
        ("AXLink", .control, "", 825, 314, 56, 20),
        ("AXButton", .control, "", 16, 326, 404, 64),
        ("AXButton", .control, "", 24, 334, 48, 48),
        ("AXButton", .control, "", 16, 390, 404, 64),
        ("AXButton", .control, "", 24, 398, 48, 48),
        ("AXLink", .control, "", 464, 436, 437, 218),
        ("AXButton", .control, "", 16, 454, 404, 64),
        ("AXButton", .control, "", 24, 462, 48, 48),
        ("AXButton", .control, "", 16, 518, 404, 64),
        ("AXButton", .control, "", 24, 526, 48, 48),
        ("AXLink", .control, "", 1118, 532, 201, 29),
        ("AXCheckBox", .control, "", 1446, 533, 24, 49),
        ("AXButton", .control, "", 1482, 533, 24, 49),
        ("AXLink", .control, "", 1118, 561, 91, 22),
        ("AXButton", .control, "", 729, 573, 49, 49),
        ("AXButton", .control, "", 777, 573, 49, 49),
        ("AXPopUpButton", .menu, "", 825, 577, 41, 41),
        ("AXButton", .control, "", 685, 581, 33, 33),
        ("AXButton", .control, "", 16, 582, 404, 64),
        ("AXButton", .control, "", 24, 590, 48, 48),
        ("AXButton", .control, "", 16, 646, 404, 64),
        ("AXButton", .control, "", 24, 654, 48, 48),
        ("AXLink", .control, "", 991, 670, 55, 49),
        ("AXButton", .control, "", 16, 710, 404, 64),
        ("AXButton", .control, "", 24, 718, 48, 48),
        ("AXButton", .control, "", 464, 725, 178, 113),
        ("AXButton", .control, "", 641, 725, 179, 113),
        ("AXButton", .control, "", 819, 725, 179, 113),
        ("AXButton", .control, "", 997, 725, 97, 113),
        ("AXButton", .control, "", 1384, 765, 106, 23),
        ("AXButton", .control, "", 16, 774, 404, 64),
        ("AXButton", .control, "", 24, 782, 48, 48),
        ("AXButton", .control, "", 1110, 834, 210, 4),
        ("AXButton", .control, "", 1320, 834, 186, 4),
        ("AXButton", .control, "", 701, 853, 32, 33),
        ("AXButton", .control, "Play", 749, 853, 32, 33),
        ("AXButton", .control, "", 797, 853, 32, 33),
        ("AXButton", .control, "", 16, 854, 56, 56),
        ("AXLink", .control, "", 88, 863, 120, 21),
        ("AXCheckBox", .control, "", 229, 866, 17, 32),
        ("AXButton", .control, "", 257, 866, 17, 32),
        ("AXCheckBox", .control, "", 1229, 866, 32, 32),
        ("AXCheckBox", .control, "", 1261, 866, 32, 32),
        ("AXCheckBox", .control, "", 1293, 866, 32, 32),
        ("AXButton", .control, "", 1325, 866, 32, 32),
        ("AXCheckBox", .control, "", 1458, 866, 32, 32),
        ("AXCheckBox", .control, "", 1490, 866, 32, 32),
        ("AXLink", .control, "", 88, 883, 78, 18),
    ]
    // Latest report, after the center card changed; content remains sanitized.
    private static let latestItems: [(String, TargetKind, String, CGFloat, CGFloat, CGFloat, CGFloat)] = [
        ("AXButton", .control, "", 96, 8, 24, 48),
        ("AXButton", .control, "", 500, 8, 48, 48),
        ("AXButton", .control, "", 556, 8, 48, 48),
        ("AXComboBox", .control, "", 556, 8, 474, 48),
        ("AXButton", .control, "", 1474, 8, 48, 48),
        ("AXButton", .control, "", 1394, 16, 32, 32),
        ("AXButton", .control, "", 1434, 16, 32, 32),
        ("AXButton", .control, "", 990, 20, 24, 25),
        ("AXButton", .control, "", 269, 80, 100, 36),
        ("AXButton", .control, "", 377, 80, 35, 36),
        ("AXButton", .control, "", 1102, 80, 16, 32),
        ("AXPopUpButton", .menu, "", 1442, 80, 32, 32),
        ("AXButton", .control, "", 1474, 80, 32, 32),
        ("AXButton", .control, "", 8, 83, 111, 30),
        ("AXCheckBox", .control, "", 476, 84, 41, 32),
        ("AXCheckBox", .control, "", 524, 84, 62, 32),
        ("AXCheckBox", .control, "", 593, 84, 82, 32),
        ("AXCheckBox", .control, "", 682, 84, 103, 32),
        ("AXMenuItem", .menu, "", 24, 132, 32, 32),
        ("AXMenuItem", .menu, "", 64, 132, 82, 32),
        ("AXLink", .control, "", 532, 137, 155, 20),
        ("AXButton", .control, "", 721, 140, 32, 32),
        ("AXButton", .control, "", 1014, 140, 32, 32),
        ("AXLink", .control, "", 825, 146, 192, 20),
        ("AXButton", .control, "", 24, 172, 32, 18),
        ("AXComboBox", .control, "", 329, 172, 75, 18),
        ("AXLink", .control, "", 532, 192, 221, 40),
        ("AXButton", .control, "", 721, 196, 32, 32),
        ("AXButton", .control, "", 1014, 196, 32, 32),
        ("AXButton", .control, "", 16, 198, 404, 64),
        ("AXLink", .control, "", 825, 202, 177, 20),
        ("AXButton", .control, "", 24, 206, 48, 48),
        ("AXButton", .control, "", 721, 252, 32, 32),
        ("AXButton", .control, "", 1014, 252, 32, 32),
        ("AXLink", .control, "", 532, 258, 68, 20),
        ("AXLink", .control, "", 825, 258, 159, 20),
        ("AXButton", .control, "", 16, 262, 404, 64),
        ("AXButton", .control, "", 24, 270, 48, 48),
        ("AXButton", .control, "", 721, 308, 32, 32),
        ("AXButton", .control, "", 1014, 308, 32, 32),
        ("AXLink", .control, "", 532, 312, 158, 24),
        ("AXLink", .control, "", 825, 314, 94, 20),
        ("AXButton", .control, "", 16, 326, 404, 64),
        ("AXButton", .control, "", 24, 334, 48, 48),
        ("AXLink", .control, "", 991, 381, 55, 48),
        ("AXButton", .control, "", 16, 390, 404, 64),
        ("AXButton", .control, "", 24, 398, 48, 48),
        ("AXButton", .control, "", 464, 436, 178, 257),
        ("AXButton", .control, "", 16, 454, 404, 64),
        ("AXButton", .control, "", 24, 462, 48, 48),
        ("AXButton", .control, "", 16, 518, 404, 64),
        ("AXButton", .control, "", 24, 526, 48, 48),
        ("AXLink", .control, "", 1118, 532, 201, 29),
        ("AXCheckBox", .control, "", 1446, 533, 24, 49),
        ("AXButton", .control, "", 1482, 533, 24, 49),
        ("AXButton", .control, "", 573, 553, 49, 49),
        ("AXLink", .control, "", 1118, 561, 91, 22),
        ("AXButton", .control, "", 16, 582, 404, 64),
        ("AXButton", .control, "", 24, 590, 48, 48),
        ("AXLink", .control, "", 476, 609, 154, 45),
        ("AXButton", .control, "", 16, 646, 404, 64),
        ("AXButton", .control, "", 24, 654, 48, 48),
        ("AXLink", .control, "", 991, 709, 55, 49),
        ("AXButton", .control, "", 16, 710, 404, 64),
        ("AXButton", .control, "", 24, 718, 48, 48),
        ("AXButton", .control, "", 464, 764, 178, 74),
        ("AXButton", .control, "", 641, 764, 179, 74),
        ("AXButton", .control, "", 819, 764, 179, 74),
        ("AXButton", .control, "", 997, 764, 97, 74),
        ("AXButton", .control, "", 1384, 765, 106, 23),
        ("AXButton", .control, "", 16, 774, 404, 64),
        ("AXButton", .control, "", 24, 782, 48, 48),
        ("AXButton", .control, "", 1110, 834, 210, 4),
        ("AXButton", .control, "", 1320, 834, 186, 4),
        ("AXButton", .control, "", 701, 853, 32, 33),
        ("AXButton", .control, "Play", 749, 853, 32, 33),
        ("AXButton", .control, "", 797, 853, 32, 33),
        ("AXButton", .control, "", 16, 854, 56, 56),
        ("AXLink", .control, "", 88, 863, 120, 21),
        ("AXCheckBox", .control, "", 229, 866, 17, 32),
        ("AXButton", .control, "", 257, 866, 17, 32),
        ("AXCheckBox", .control, "", 1229, 866, 32, 32),
        ("AXCheckBox", .control, "", 1261, 866, 32, 32),
        ("AXCheckBox", .control, "", 1293, 866, 32, 32),
        ("AXButton", .control, "", 1325, 866, 32, 32),
        ("AXCheckBox", .control, "", 1458, 866, 32, 32),
        ("AXCheckBox", .control, "", 1490, 866, 32, 32),
        ("AXLink", .control, "", 88, 883, 78, 18),
    ]
    let palette: ThemePalette
    let controls: [Target]
    let playerFrame = CGRect(x: 24, y: 64, width: 1530, height: 926)
    var instruction = "Choose the region containing Play"
    init(dark: Bool, home: Bool = false, latest: Bool = false) {
        let items = latest ? Self.latestItems : (home ? Self.homeItems : Self.items)
        palette = ThemePalette(theme: .glitch, dark: dark)
        let labels = Hints.labels(count: items.count)
        controls = items.enumerated().map { index, item in
            Target(element: AXUIElementCreateApplication(0),
                frame: CGRect(x: 24 + item.3, y: 64 + item.4, width: item.5, height: item.6),
                label: labels[index], kind: item.1, action: "AXPress", clicksMenuBarExtra: false,
                metadata: TargetMetadata(role: item.0, subrole: "", title: item.2.isEmpty ? "Action \(index + 1)" : item.2,
                                         description: "", owner: 0, bundleID: "preview"))
        }
        super.init(frame: CGRect(x: 0, y: 0, width: 1578, height: 1030))
        appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func local(_ frame: CGRect) -> CGRect {
        CGRect(x: frame.minX, y: bounds.height - frame.maxY, width: frame.width, height: frame.height)
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(rgb: palette.background).setFill(); bounds.fill()
        NSColor(rgb: palette.surface).setFill()
        NSBezierPath(roundedRect: local(playerFrame), xRadius: 8, yRadius: 8).fill()
        for control in controls {
            let rect = local(control.frame)
            NSColor(rgb: palette.text).withAlphaComponent(0.12).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
            if control.metadata.title == "Play" {
                NSColor(rgb: palette.text).setFill()
                let triangle = NSBezierPath()
                triangle.move(to: CGPoint(x: rect.minX + 11, y: rect.minY + 8))
                triangle.line(to: CGPoint(x: rect.maxX - 8, y: rect.midY))
                triangle.line(to: CGPoint(x: rect.minX + 11, y: rect.maxY - 8))
                triangle.close(); triangle.fill()
            }
        }
        (instruction as NSString).draw(at: CGPoint(x: 24, y: bounds.height - 32), withAttributes:
            [.font: NSFont.systemFont(ofSize: 16, weight: .semibold), .foregroundColor: NSColor(rgb: palette.text)])
        ("RENDERED FIXTURE · SANITIZED PLAYER GEOMETRY · \(controls.count) CONTROLS · SYNTHETIC CONTENT" as NSString)
            .draw(at: CGPoint(x: 24, y: 16), withAttributes:
                [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor(rgb: palette.text)])
    }

    static func render(to directory: URL) throws {
        for variant in 0..<3 {
        let home = variant > 0, latest = variant == 2
        for dark in [false, true] {
            for size: CGFloat in [10, 16, 22] {
                let view = PlayerSectionPreview(dark: dark, home: home, latest: latest)
                let canvas = HintCanvas(frame: view.bounds)
                canvas.screenFrame = view.bounds; canvas.desktopTop = view.bounds.height
                canvas.fontSize = size; canvas.palette = view.palette
                canvas.windowFrame = view.playerFrame
                var navigation = SectionNavigation()
                let root = navigation.reset(view.controls, scopedPopup: false, configuration: .standard, windowFrame: view.playerFrame)
                let tabs = view.controls.filter { $0.kind == .tab }
                guard view.controls.count == (latest ? 88 : (home ? 89 : 73)), navigation.sectionCount == 3,
                      root.flatMap(\.sectionMemberFrames).count == view.controls.count - tabs.count,
                      let play = view.controls.first(where: { $0.metadata.title == "Play" }),
                      let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw CocoaError(.coderInvalidValue) }
                view.addSubview(canvas)
                for level in 0..<3 {
                    canvas.targets = navigation.targets
                    canvas.scopeFrame = navigation.scopeFrame ?? view.playerFrame
                    canvas.canGoBack = navigation.depth > 0
                    canvas.prefersActionPanel = navigation.prefersActionPanel
                    canvas.prefix = ""; canvas.ledgerPage = 0
                    let next = navigation.targets.first { $0.sectionMemberFrames.contains(play.frame) }
                    // The pane containing playback must reach the actual window
                    // bottom even though seeking is deliberately not a target.
                    guard (next?.frame ?? navigation.scopeFrame)?.maxY == view.playerFrame.maxY,
                          !navigation.targets.contains(where: { $0.metadata.role == "AXSlider" }) else { throw CocoaError(.coderInvalidValue) }
                    if let next {
                        view.instruction = "Level \(level + 1) · \(next.label.uppercased()) narrows the region containing Play"
                    } else {
                        guard let target = navigation.targets.first(where: { $0.frame == play.frame }) else { throw CocoaError(.coderInvalidValue) }
                        view.instruction = "Level \(level + 1) · \(target.label.uppercased()) selects Play"
                    }
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    // Narrow from three regions, to two, to direct controls.
                    // Tabs remain reachable without changing region membership.
                    guard navigation.depth == level, navigation.sectionCount == [3, 2, 0][level],
                          navigation.targets.filter({ $0.kind == .tab }).map(\.frame) == (level == 0 ? tabs.map(\.frame) : []),
                          canvas.drawnLabels == Set(navigation.targets.map(\.label)) else { throw CocoaError(.coderInvalidValue) }
                    try bitmap.representation(using: .png, properties: [:])!.write(to:
                        directory.appendingPathComponent("layout-player\(latest ? "-latest" : (home ? "-home" : ""))-level\(level + 1)-\(Int(size))-\(dark ? "dark" : "light").png"))
                    if let next {
                        guard canvas.regionMarkerFrames[next.label] != nil,
                              navigation.select(next.label, configuration: .standard),
                              navigation.targets.map(\.frame) != canvas.targets.map(\.frame) else { throw CocoaError(.coderInvalidValue) }
                    } else {
                        guard level == 2, (1...18).contains(navigation.regionTargets.count),
                              let target = navigation.targets.first(where: { $0.frame == play.frame }),
                              target.action == "AXPress", canvas.localBadgeFrames[target.label] != nil else {
                            throw CocoaError(.coderInvalidValue, userInfo: [NSLocalizedDescriptionKey:
                                "Player variant \(variant), size \(size), level \(level): \(navigation.regionTargets.count) controls; Play must have a local press hint."])
                        }
                        let before = canvas.localBadgeFrames
                        canvas.prefix = target.label
                        view.cacheDisplay(in: view.bounds, to: bitmap)
                        guard canvas.drawnLabels == [target.label],
                              canvas.localBadgeFrames == [target.label: before[target.label]!],
                              !navigation.select(target.label, configuration: .standard) else { throw CocoaError(.coderInvalidValue) }
                    }
                }
                guard navigation.back(), navigation.back(), navigation.depth == 0,
                      navigation.targets.map(\.label) == root.map(\.label),
                      navigation.targets.map(\.frame) == root.map(\.frame) else { throw CocoaError(.coderInvalidValue) }
            }
        }
        }
    }
}
#endif
