#if DEBUG
import AppKit
import SwiftUI
import ApplicationServices
import OpenSesameCore
import OpenSesameBrand

// Development-only fixtures use the real views without starting the controller.
// Release builds contain neither the synthetic UI nor its rendering code.
enum DevelopmentPreviews {
    static func render(to directory: URL) throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        NSApp.appearance = NSAppearance(named: .darkAqua)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let model = Controller()
        model.trusted = true
        for page in DashboardPage.allCases {
            let view = NSHostingView(rootView: Dashboard(model: model, page: page))
            view.appearance = NSAppearance(named: .darkAqua)
            view.frame = CGRect(origin: .zero, size: view.fittingSize)
            view.layoutSubtreeIfNeeded()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("settings-\(page.rawValue.lowercased()).png"))
        }
        for theme in AppTheme.allCases {
            model.theme = theme
            for mode in [AppearanceMode.dark, .light] {
                model.appearanceMode = mode
                NSApp.appearance = NSAppearance(named: mode == .dark ? .darkAqua : .aqua)
                let view = NSHostingView(rootView: Dashboard(model: model, page: .style))
                view.appearance = NSAppearance(named: mode == .dark ? .darkAqua : .aqua)
                view.frame = CGRect(origin: .zero, size: view.fittingSize)
                view.layoutSubtreeIfNeeded()
                guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("theme-\(theme.rawValue)-\(mode.rawValue).png"))
            }
        }
        try PopupLayoutPreview.render(to: directory)
        try OverflowPreview.render(to: directory)
        try OverflowPreview.renderMixed(to: directory)
    }
}

/// Neutral fixtures based on the reported widget geometry; no live app content.
private final class PopupLayoutPreview: NSView {
    struct Item { let title: String, role: String; let frame: CGRect }
    let items: [Item]
    let popup: CGRect
    let heading: String
    init(size: CGSize, popup: CGRect, items: [Item], heading: String) {
        self.popup = popup; self.items = items; self.heading = heading
        super.init(frame: CGRect(origin: .zero, size: size))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func local(_ frame: CGRect) -> CGRect { CGRect(x: frame.minX, y: bounds.height - frame.maxY, width: frame.width, height: frame.height) }
    var textObstacles: [CGRect] { items.filter { $0.frame.width > 70 }.map { item in
        CGRect(x: item.frame.minX + 10, y: item.frame.minY + 8, width: min(item.frame.width - 20, 105), height: 14)
    } }
    override func draw(_ dirtyRect: NSRect) {
        BrandArtwork.background.setFill(); bounds.fill()
        (heading as NSString).draw(at: CGPoint(x: 24, y: bounds.maxY - 30), withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold), .foregroundColor: BrandArtwork.teal])
        NSColor(white: 0.12, alpha: 1).setFill()
        NSBezierPath(roundedRect: local(popup), xRadius: 14, yRadius: 14).fill()
        for item in items {
            let rect = local(item.frame)
            NSColor(white: 0.20, alpha: 1).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5).fill()
            let visible = item.frame.width < 40 ? item.title.replacingOccurrences(of: " minutes", with: "").replacingOccurrences(of: " hours", with: "h").replacingOccurrences(of: " hour", with: "h").replacingOccurrences(of: "Custom duration", with: "…") : item.title
            (visible as NSString).draw(at: CGPoint(x: rect.minX + (rect.width > 70 ? 10 : 3), y: rect.maxY - 22), withAttributes: [.font: NSFont.systemFont(ofSize: rect.width > 70 ? 12 : 10), .foregroundColor: NSColor.white])
        }
        ("RENDERED FIXTURE · ACTUAL HINT CANVAS" as NSString).draw(at: CGPoint(x: 24, y: 20), withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 10, weight: .medium), .foregroundColor: NSColor.lightGray])
    }
    static func render(to directory: URL) throws {
        func item(_ title: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, role: String = "AXButton") -> Item {
            Item(title: title, role: role, frame: CGRect(x: x, y: y, width: width, height: height))
        }
        let controlCenter = [item("Wi-Fi",300,80,140,64,role:"AXCheckBox"), item("Media",453,80,140,140,role:"AXGroup"),
            item("Bluetooth",300,156,140,64,role:"AXCheckBox"), item("▶",508,176,30,30),
            item("AirDrop",300,232,140,64,role:"AXCheckBox"), item("Stage",453,232,64,64,role:"AXCheckBox"), item("Mirror",529,232,64,64,role:"AXCheckBox"),
            item("Dark",300,308,64,64,role:"AXCheckBox"), item("Capture",376,308,64,64), item("Focus",453,308,140,64,role:"AXCheckBox"),
            item("Display",300,384,293,64,role:"AXGroup"), item("Sound",300,460,293,64,role:"AXGroup"), item("Edit Controls",399,540,94,24)]
        var durations = [item("Enabled",565,72,51,23), item("Duration",346,119,267,15)]
        for (index, x) in [346,385,417,449,488,520,552,591].enumerated() {
            durations.append(item(["∞","15 minutes","30 minutes","45 minutes","1 hour","4 hours","8 hours","Custom duration"][index],CGFloat(x),144,24,24))
        }
        durations += [item("Settings",346,187,267,15), item("About",346,219,37,16)]
        var expanded = Array(durations.dropLast())
        for index in 0..<8 { expanded.append(item("Setting \(index + 1)",346,213 + CGFloat(index) * 36,202,28)) }
        for index in 0..<9 { expanded.append(item(["Accent", "Blue", "Purple", "Pink", "Red", "Orange", "Yellow", "Green", "Graphite"][index],360 + CGFloat(index) * 28,506,16,16)) }
        expanded += [item("Shortcuts",346,535,202,28), item("Advanced",346,571,202,28), item("Help",346,607,202,28), item("About",346,655,37,16)]
        let fixtures: [(String, CGRect, CGRect, [Item])] = [
            ("paged-popup",CGRect(x:330,y:60,width:300,height:645),CGRect(x:330,y:60,width:300,height:645),(0..<40).map { item("Menu action \($0 + 1)",346,80 + CGFloat($0) * 14,260,14,role:"AXMenuItem") }),
            ("expanded-popup",CGRect(x:330,y:60,width:300,height:645),CGRect(x:330,y:60,width:300,height:645),expanded),
            ("control-center",CGRect(x:128,y:40,width:656,height:640),CGRect(x:288,y:68,width:317,height:510),controlCenter),
            ("duration-row",CGRect(x:330,y:60,width:300,height:209),CGRect(x:330,y:60,width:300,height:209),durations),
            ("media-pair",CGRect(x:128,y:40,width:656,height:640),CGRect(x:300,y:80,width:300,height:150),[item("Now Playing",315,95,140,20,role:"AXStaticText"),item("▶",480,100,30,30),item("▶|",510,100,30,30),item("Another Source",315,173,140,20,role:"AXStaticText"),item("▶",480,178,30,30)])]
        for (name, host, popup, items) in fixtures {
            let view = PopupLayoutPreview(size: CGSize(width: 1120, height: name == "expanded-popup" ? 1200 : 720), popup: popup, items: items, heading: name.uppercased())
            let canvas = HintCanvas(frame: view.bounds)
            canvas.screenFrame = view.bounds; canvas.desktopTop = view.bounds.height
            canvas.scopeFrame = host; canvas.scopedPopup = true; canvas.textFrames = view.textObstacles
            canvas.ledgerPage = name == "paged-popup" ? 1 : 0
            let actionable = items.filter { $0.role != "AXStaticText" }
            let labels = LedgerLayout.labels(frames: actionable.map { $0.frame })
            canvas.targets = actionable.enumerated().map { index, item in
                Target(element: AXUIElementCreateApplication(0), frame: item.frame, label: labels[index], kind: .control, action: "AXPress", clicksMenuBarExtra: false,
                       metadata: TargetMetadata(role: item.role, subrole: "", title: item.title, description: item.title, owner: 0, bundleID: "preview"))
            }
            view.addSubview(canvas)
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw CocoaError(.coderInvalidValue) }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            if name != "paged-popup" {
                let missing = Set(canvas.targets.map(\.label)).subtracting(canvas.drawnLabels)
                guard missing.isEmpty else {
                    fputs("Missing fixture hints in \(name): \(missing.sorted())\n", stderr)
                    throw CocoaError(.coderInvalidValue)
                }
            }
            try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("layout-\(name).png"))
            // Detail crops make the actual hint typography readable in README
            // cards without including user windows or private app content.
            let crop: CGRect? = name == "duration-row" ? CGRect(x: 170, y: 25, width: 620, height: 370)
                : (name == "media-pair" ? CGRect(x: 280, y: 65, width: 340, height: 200) : nil)
            if let crop, let detail = bitmap.cgImage?.cropping(to: crop) {
                try NSBitmapImageRep(cgImage: detail).representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("detail-\(name).png"))
            }
        }
    }
}

/// Exhaustively checks real renderer pagination without starting the app,
/// installing input hooks, or interacting with live Accessibility controls.
private enum OverflowPreview {
    static func renderMixed(to directory: URL) throws {
        let canvas = HintCanvas(frame: CGRect(x: 0, y: 0, width: 1000, height: 600))
        canvas.screenFrame = canvas.bounds; canvas.desktopTop = canvas.bounds.height
        func target(_ code: String, _ frame: CGRect, _ kind: TargetKind, _ role: String) -> Target {
            Target(element: AXUIElementCreateApplication(0), frame: frame, label: code, kind: kind,
                action: "AXPress", clicksMenuBarExtra: false,
                metadata: TargetMetadata(role: role, subrole: "", title: "Example", description: "", owner: 0, bundleID: "com.mitchellh.ghostty"))
        }
        canvas.targets = [target("ss", CGRect(x: 40, y: 0, width: 30, height: 24), .menu, "AXMenuBarItem"),
            target("sa", CGRect(x: 300, y: 70, width: 180, height: 28), .tab, "AXTab"),
            target("sd", CGRect(x: 900, y: 380, width: 8, height: 8), .window, "AXWindow")]
        guard let bitmap = canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds) else { throw CocoaError(.coderInvalidValue) }
        canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
        guard canvas.localLabels == ["ss", "sa"], canvas.overflowLabels == ["sd"],
              canvas.drawnLabels == ["ss", "sa", "sd"] else {
            fputs("Mixed overflow must preserve local menu and tab markers.\n", stderr)
            throw CocoaError(.coderInvalidValue)
        }
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("layout-mixed-overflow.png"))
    }

    static func render(to directory: URL) throws {
        for sections in [false, true] {
            let canvas = HintCanvas(frame: CGRect(x: 0, y: 0, width: 520, height: 320))
            canvas.screenFrame = canvas.bounds; canvas.desktopTop = canvas.bounds.height
            canvas.fontSize = 22
            let frame = CGRect(x: 60, y: 40, width: 400, height: 210)
            canvas.scopeFrame = frame
            // No local gutters: force deliberate overflow, not missing codes.
            canvas.textFrames = [canvas.bounds]
            let labels = Hints.labels(count: 45, configuration: try HintConfiguration(minimumLength: 3, alphabet: "sadfjklewcmpgh", prefix: "s"))
            canvas.targets = labels.enumerated().map { index, label in
                Target(element: AXUIElementCreateApplication(0), frame: frame, label: label,
                    kind: .control, action: "AXPress", clicksMenuBarExtra: false,
                    metadata: TargetMetadata(role: sections ? "OpenSesameSection" : "AXButton", subrole: "",
                        title: sections ? "Section \(index + 1)" : "Action \(index + 1)", description: "", owner: 0, bundleID: "preview"))
            }
            var reached = Set<String>()
            for page in 0..<45 {
                canvas.ledgerPage = page
                guard let bitmap = canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds) else { throw CocoaError(.coderInvalidValue) }
                canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
                guard canvas.usesLedger, !canvas.drawnLabels.isEmpty else { throw CocoaError(.coderInvalidValue) }
                reached.formUnion(canvas.drawnLabels)
                if page == 0 {
                    try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(sections ? "layout-section-overflow.png" : "layout-overflow.png"))
                }
                if reached == Set(labels) { break }
            }
            guard reached == Set(labels) else { throw CocoaError(.coderInvalidValue) }
            canvas.prefix = labels.last!
            guard let bitmap = canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds) else { throw CocoaError(.coderInvalidValue) }
            canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
            guard canvas.drawnLabels == [labels.last!] else { throw CocoaError(.coderInvalidValue) }
        }
    }
}

#endif
