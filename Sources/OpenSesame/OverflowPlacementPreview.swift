#if DEBUG
import AppKit
import ApplicationServices
import OpenSesameCore

/// Shared geometry contract, rendered with two providers and both appearances.
enum OverflowPlacementPreview {
    static func render(to directory: URL) throws {
        for dark in [false, true] {
            try renderOwners(to: directory, dark: dark)
            for (name, window) in [
                ("right", CGRect(x: 380, y: 60, width: 400, height: 640)),
                ("left", CGRect(x: 850, y: 60, width: 380, height: 640)),
                ("inside", CGRect(x: 0, y: 0, width: 1280, height: 760))
            ] {
                var reference: CGRect?
                for bundle in ["com.google.Chrome", "com.apple.Terminal"] {
                    let view = NSView(frame: CGRect(x: 0, y: 0, width: 1280, height: 760))
                    let palette = ThemePalette(theme: .glitch, dark: dark)
                    view.wantsLayer = true; view.layer?.backgroundColor = NSColor(rgb: palette.surface).cgColor
                    let pane = NSView(frame: CGRect(x: window.minX, y: view.bounds.height - window.maxY, width: window.width, height: window.height))
                    pane.wantsLayer = true; pane.layer?.backgroundColor = NSColor(rgb: palette.background).cgColor
                    view.addSubview(pane)
                    let canvas = HintCanvas(frame: view.bounds)
                    canvas.palette = palette; canvas.screenFrame = view.bounds; canvas.desktopTop = view.bounds.height
                    canvas.windowFrame = window; canvas.scopeFrame = window.insetBy(dx: 40, dy: 80)
                    canvas.appName = bundle == "com.google.Chrome" ? "Chrome" : "Terminal"
                    canvas.appIcon = AppIdentity.icon(bundleID: bundle)
                    canvas.prefersActionPanel = true
                    canvas.targets = Hints.labels(count: 50).enumerated().map { index, code in
                        Target(element: AXUIElementCreateApplication(0), frame: window.insetBy(dx: 80, dy: 120), label: code,
                            kind: .control, action: "AXPress", clicksMenuBarExtra: false,
                            metadata: TargetMetadata(role: "AXButton", subrole: "", title: "Example action \(index + 1)", description: "", owner: 0, bundleID: bundle))
                    }
                    view.addSubview(canvas)
                    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw CocoaError(.coderInvalidValue) }
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    guard let panel = canvas.ledgerPanelFrame, view.bounds.contains(panel), reference == nil || reference == panel else { throw CocoaError(.coderInvalidValue) }
                    if name == "right", panel.minX != window.maxX + 12 { throw CocoaError(.coderInvalidValue) }
                    if name == "left", panel.maxX != window.minX - 12 { throw CocoaError(.coderInvalidValue) }
                    reference = panel
                    try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(
                        "overflow-\(name)-\(canvas.appName.lowercased())-\(dark ? "dark" : "light").png"))
                }
            }
        }
    }
    private static func renderOwners(to directory: URL, dark: Bool) throws {
        let canvas = HintCanvas(frame: CGRect(x: 0, y: 0, width: 1000, height: 640))
        canvas.palette = ThemePalette(theme: .glitch, dark: dark)
        canvas.screenFrame = canvas.bounds; canvas.desktopTop = canvas.bounds.height
        canvas.windowFrame = CGRect(x: 100, y: 70, width: 580, height: 500)
        canvas.scopeFrame = canvas.windowFrame; canvas.owner = 42
        canvas.targets = [
            ("ss", "Accessibility — Apple Developer Documentation", "com.google.Chrome", Int32(42), TargetKind.tab),
            ("sa", "OpenSesame keyboard navigation and saved places", "com.google.Chrome", Int32(42), .tab),
            ("sd", "Research — 4 tabs", "com.google.Chrome", Int32(42), .tab),
            ("sf", "Screenshot.png", "com.apple.finder", Int32(43), .desktop)
        ].enumerated().map { index, item in
            Target(element: AXUIElementCreateApplication(0), frame: CGRect(x: 200 + index * 90, y: 100, width: 8, height: 8),
                label: item.0, kind: item.4, action: "AXPress", clicksMenuBarExtra: false,
                metadata: .init(role: item.4 == .tab ? "AXRadioButton" : "AXImage", subrole: "", title: item.1,
                    description: "", owner: item.3, bundleID: item.2))
        }
        for (page, source) in [(0, "browser"), (1, "desktop")] {
            canvas.ledgerPage = page
            guard let bitmap = canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds) else { throw CocoaError(.coderInvalidValue) }
            canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
            guard canvas.ledgerPageCount == 2,
                  canvas.ledgerCaptions.count == (page == 0 ? 3 : 1),
                  canvas.ledgerCaptions["sf"] == (page == 0 ? nil : "Screenshot.png") else { throw CocoaError(.coderInvalidValue) }
            try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(
                "overflow-owner-\(source)-\(dark ? "dark" : "light").png"))
        }
    }

}
#endif
