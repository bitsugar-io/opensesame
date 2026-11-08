#if DEBUG
import AppKit
import ApplicationServices
import OpenSesameCore

/// Production canvas over synthetic content: semantic tag colors and compact
/// typography beside the original large window code, in both appearances.
final class HintAppearancePreview: NSView {
    let palette: ThemePalette
    let menuNames = ["App", "File", "Edit", "View", "Window", "Help"]
    let menus = (0..<6).map { CGRect(x: 32 + $0 * 76, y: 0, width: 68, height: 26) }
    let menuExtras = [CGRect(x: 1000, y: 0, width: 34, height: 26), CGRect(x: 1100, y: 0, width: 34, height: 26)]
    let desktopItem = CGRect(x: 1100, y: 606, width: 64, height: 64)
    let tabs = (0..<3).map { CGRect(x: 480 + $0 * 224, y: 142, width: 208, height: 38) }
    let controls: [CGRect] = (0..<6).map { index in
        let x = CGFloat(496 + (index % 3) * 220)
        let y = CGFloat(270 + (index / 3) * 180)
        return CGRect(x: x, y: y, width: 100, height: 32)
    }
    let controlNames = ["Previous", "Play", "Next", "Search", "Save", "Share"]
    let otherWindow = CGRect(x: 24, y: 100, width: 400, height: 500)
    let currentWindow = CGRect(x: 456, y: 100, width: 720, height: 500)
    init(dark: Bool) {
        palette = ThemePalette(theme: .glitch, dark: dark)
        super.init(frame: CGRect(x: 0, y: 0, width: 1200, height: 680))
        appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func local(_ frame: CGRect) -> CGRect {
        CGRect(x: frame.minX, y: bounds.height - frame.maxY, width: frame.width, height: frame.height)
    }
    private func text(_ value: String, at point: CGPoint, color: UInt32? = nil, size: CGFloat = 12) {
        (value as NSString).draw(at: point, withAttributes:
            [.font: NSFont.systemFont(ofSize: size), .foregroundColor: NSColor(rgb: color ?? palette.text)])
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(rgb: palette.background).setFill(); bounds.fill()
        for window in [otherWindow, currentWindow] {
            NSColor(rgb: palette.surface).setFill()
            NSBezierPath(roundedRect: local(window), xRadius: 8, yRadius: 8).fill()
        }
        text("Other window", at: CGPoint(x: 40, y: local(otherWindow).maxY - 28))
        text("Current window", at: CGPoint(x: 472, y: local(currentWindow).maxY - 28))
        for (name, frame) in zip(menuNames, menus) {
            text(name, at: CGPoint(x: frame.minX + 8, y: local(frame).midY - 7))
        }
        for (name, frame) in zip(["GIF", "Wi-Fi"], menuExtras) {
            text(name, at: CGPoint(x: frame.minX, y: local(frame).midY - 7))
        }
        let desktop = local(desktopItem)
        NSColor(rgb: palette.text).withAlphaComponent(0.1).setFill()
        NSBezierPath(roundedRect: desktop, xRadius: 4, yRadius: 4).fill()
        text("File", at: CGPoint(x: desktop.minX + 8, y: desktop.midY - 7))
        for (index, frame) in tabs.enumerated() {
            let rect = local(frame)
            NSColor(rgb: palette.background).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
            text("Tab \(index + 1)", at: CGPoint(x: rect.minX + 12, y: rect.midY - 7))
        }
        for (name, frame) in zip(controlNames, controls) {
            let rect = local(frame)
            NSColor(rgb: palette.text).withAlphaComponent(0.08).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
            text(name, at: CGPoint(x: rect.minX + 12, y: rect.midY - 7))
        }
        text("Menus", at: CGPoint(x: 32, y: 44), color: palette.alternate)
        text("Tabs", at: CGPoint(x: 150, y: 44), color: palette.tab)
        text("Controls", at: CGPoint(x: 240, y: 44), color: palette.control)
        text("Desktop", at: CGPoint(x: 360, y: 44), color: palette.window)
        text("RENDERED FIXTURE · ACTUAL HINT CANVAS · SYNTHETIC CONTENT", at: CGPoint(x: 32, y: 20), size: 10)
    }
    static func render(to directory: URL) throws {
        for dark in [false, true] {
            for size: CGFloat in [10, 16, 22] {
                let view = HintAppearancePreview(dark: dark)
                let canvas = HintCanvas(frame: view.bounds)
                canvas.screenFrame = view.bounds; canvas.desktopTop = view.bounds.height
                canvas.palette = view.palette; canvas.fontSize = size; canvas.scopeFrame = view.currentWindow
                var items: [(CGRect, TargetKind, String, String)] = []
                for (index, frame) in view.menus.enumerated() {
                    items.append((frame, .menu, "AXMenuBarItem", view.menuNames[index]))
                }
                items.append((view.menuExtras[0], .menu, "AXMenuBarItem", ""))
                items.append((view.menuExtras[1], .menu, "AXMenuBarItem", "Wi-Fi"))
                items.append((view.otherWindow, .window, "AXWindow", "Other window"))
                for (index, frame) in view.tabs.enumerated() {
                    items.append((frame, .tab, "AXTab", "Tab \(index + 1)"))
                }
                for (index, frame) in view.controls.enumerated() {
                    items.append((frame, .control, "AXButton", view.controlNames[index]))
                }
                items.append((view.desktopItem, .desktop, "AXImage", "File"))
                let labels = Hints.labels(count: items.count)
                canvas.targets = zip(items, labels).map { item, code in
                    Target(element: AXUIElementCreateApplication(0), frame: item.0, label: code, kind: item.1,
                        action: item.1 == .window ? "AXRaise" : "AXPress", clicksMenuBarExtra: false,
                        metadata: TargetMetadata(role: item.2, subrole: "", title: item.3, description: "", owner: 0, bundleID: "preview"))
                }
                canvas.textFrames = view.tabs.map { CGRect(x: $0.minX + 12, y: $0.midY - 8, width: 44, height: 16) }
                view.addSubview(canvas)
                guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw CocoaError(.coderInvalidValue) }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard canvas.drawnLabels == Set(labels), canvas.regionMarkerFrames.count == 1,
                      !canvas.usesLedger else { throw CocoaError(.coderInvalidValue) }
                let colors = canvas.drawnAccents, frames = canvas.localBadgeFrames
                guard canvas.associatedLabels.isEmpty else { throw CocoaError(.coderInvalidValue) }
                for kind in [TargetKind.menu, .tab, .control, .desktop] {
                    let family = canvas.targets.filter { $0.kind == kind }
                    for (index, target) in family.enumerated() {
                        guard colors[target.label] == HintStyle.colors(kind: kind, index: index, palette: view.palette).accent else { throw CocoaError(.coderInvalidValue) }
                    }
                }
                try bitmap.representation(using: .png, properties: [:])!.write(to:
                    directory.appendingPathComponent("hint-appearance-\(Int(size))-\(dark ? "dark" : "light").png"))
                for target in canvas.targets {
                    canvas.prefix = target.label
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    guard canvas.drawnLabels == [target.label], canvas.drawnAccents == [target.label: colors[target.label]!],
                          canvas.localBadgeFrames == [target.label: frames[target.label]!] else { throw CocoaError(.coderInvalidValue) }
                }
                // Overflow must use the same semantic family and shade as the
                // local tag, even though its position and rendering change.
                canvas.prefix = ""; canvas.prefersActionPanel = true
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard canvas.drawnLabels == Set(labels), canvas.drawnAccents == colors else { throw CocoaError(.coderInvalidValue) }
            }
        }
    }
}
#endif
