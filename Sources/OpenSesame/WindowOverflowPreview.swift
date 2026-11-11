#if DEBUG
import AppKit
import ApplicationServices
import OpenSesameCore

/// Sanitized reproduction of a foreground panel covering a background window's
/// first code placement. Both providers use the same production canvas.
enum WindowOverflowPreview {
    static func canvas(onLeft: Bool = false, bundleID: String = "preview.foreground") -> HintCanvas {
        let view = HintCanvas(frame: CGRect(x: 0, y: 0, width: 1600, height: 900))
        view.screenFrame = view.bounds; view.desktopTop = view.bounds.height
        view.windowFrame = onLeft ? CGRect(x: 500, y: 50, width: 1000, height: 800)
            : CGRect(x: 300, y: 50, width: 800, height: 800)
        view.scopeFrame = view.windowFrame; view.owner = 1; view.appName = "Example app"
        let window = CGRect(x: onLeft ? 0 : 800, y: 30, width: 800, height: 870)
        let exposed = VisibleRegion.exposed(frame: window, screens: [view.bounds], occluders: [view.windowFrame!])
        let choice = Target(element: AXUIElementCreateApplication(2), frame: window, label: "sss", kind: .window,
            action: "AXRaise", clicksMenuBarExtra: false,
            metadata: TargetMetadata(role: "AXWindow", subrole: "", title: "Background window", description: "",
                                     owner: 2, bundleID: "preview.background", visibleFrames: exposed))
        let tabs = Hints.labels(count: 50).enumerated().map { index, code in
            let x = view.windowFrame!.minX + 30 + CGFloat(index * 14)
            return Target(element: AXUIElementCreateApplication(1), frame: CGRect(x: x, y: 65, width: 8, height: 24),
                label: "a" + code, kind: .tab, action: "AXPress", clicksMenuBarExtra: false,
                metadata: TargetMetadata(role: "AXTab", subrole: "", title: "Example tab \(index + 1)", description: "",
                                         owner: 1, bundleID: bundleID))
        }
        view.targets = [choice] + tabs
        return view
    }

    static func render(to directory: URL) throws {
        for dark in [false, true] {
            for onLeft in [false, true] {
                for size: CGFloat in [10, 16, 22] {
                    var reference: CGRect?
                    for provider in ["com.google.Chrome", "com.apple.Terminal"] {
                        let canvas = canvas(onLeft: onLeft, bundleID: provider)
                        canvas.fontSize = size; canvas.palette = ThemePalette(theme: .glitch, dark: dark)
                        let view = NSView(frame: canvas.bounds)
                        view.wantsLayer = true; view.layer?.backgroundColor = NSColor(rgb: canvas.palette.surface).cgColor
                        view.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                        let frame = canvas.windowFrame!
                        let pane = NSView(frame: CGRect(x: frame.minX, y: view.bounds.height - frame.maxY, width: frame.width, height: frame.height))
                        pane.wantsLayer = true; pane.layer?.backgroundColor = NSColor(rgb: canvas.palette.background).cgColor
                        view.addSubview(pane)
                        let title = NSTextField(labelWithString: "RENDERED EXAMPLE · ACTIVE APP WITH CROWDED TABS")
                        title.textColor = NSColor(rgb: canvas.palette.text)
                        title.frame = CGRect(x: frame.minX + 24, y: view.bounds.height - frame.minY - 60, width: frame.width - 48, height: 24)
                        view.addSubview(title); view.addSubview(canvas)
                        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw CocoaError(.coderInvalidValue) }
                        view.cacheDisplay(in: view.bounds, to: bitmap)
                        guard let marker = canvas.regionMarkerFrames["sss"], let panel = canvas.ledgerPanelFrame,
                              !panel.insetBy(dx: -5, dy: -5).intersects(marker), reference == nil || reference == marker,
                              !canvas.overflowLabels.contains("sss") else { throw CocoaError(.coderInvalidValue) }
                        reference = marker
                        let suffix = provider == "com.google.Chrome" ? "browser" : "native"
                        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(
                            "window-overflow-\(onLeft ? "left" : "right")-\(suffix)-\(Int(size))-\(dark ? "dark" : "light").png"))
                    }
                }
            }
        }
    }
}
#endif
