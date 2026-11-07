#if DEBUG
import AppKit
import ApplicationServices
import OpenSesameCore

/// Synthetic desktop with an exposed background window, a second app, and
/// tabs only in the current window. Uses the production discovery/marker paths.
final class WindowSelectionPreview: NSView {
    let palette: ThemePalette
    let surfaces: [Surface] = [
        Surface(id: 1, pid: 11, frame: CGRect(x: 760, y: 90, width: 600, height: 660)),
        Surface(id: 2, pid: 22, frame: CGRect(x: 560, y: 240, width: 300, height: 420)),
        Surface(id: 3, pid: 11, frame: CGRect(x: 24, y: 70, width: 660, height: 740)),
        Surface(id: 4, pid: 11, frame: CGRect(x: 720, y: 32, width: 680, height: 820))
    ]
    let tabs = (0..<3).map { CGRect(x: 780 + $0 * 184, y: 106, width: 176, height: 36) }
    init(dark: Bool) {
        palette = ThemePalette(theme: .glitch, dark: dark)
        super.init(frame: CGRect(x: 0, y: 0, width: 1440, height: 900))
        appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func local(_ frame: CGRect) -> CGRect { CGRect(x: frame.minX, y: bounds.height - frame.maxY, width: frame.width, height: frame.height) }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(rgb: palette.background).setFill(); bounds.fill()
        for surface in surfaces.reversed() {
            let rect = local(surface.frame)
            NSColor(rgb: surface.pid == 22 ? palette.background : palette.surface).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
            NSColor(rgb: palette.text).withAlphaComponent(0.25).setStroke()
            let edge = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8); edge.lineWidth = 1; edge.stroke()
            let title = surface.pid == 22 ? "Player" : "Terminal \(surface.id)"
            (title as NSString).draw(at: CGPoint(x: rect.minX + 16, y: rect.maxY - 23), withAttributes:
                [.font: NSFont.systemFont(ofSize: 12, weight: .medium), .foregroundColor: NSColor(rgb: palette.text)])
            NSColor(rgb: palette.text).withAlphaComponent(0.08).setFill()
            for row in 0..<12 {
                CGRect(x: rect.minX + 20, y: rect.maxY - 80 - CGFloat(row) * 32,
                       width: rect.width * (row.isMultiple(of: 3) ? 0.65 : 0.8), height: 8).fill()
            }
        }
        for (index, tab) in tabs.enumerated() {
            let rect = local(tab)
            NSColor(rgb: palette.background).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
            ("Project \(index + 1)" as NSString).draw(at: CGPoint(x: rect.minX + 12, y: rect.midY - 7), withAttributes:
                [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor(rgb: palette.text)])
        }
        ("RENDERED FIXTURE · VISIBLE WINDOWS ACROSS APPS · CURRENT-WINDOW TABS" as NSString).draw(at: CGPoint(x: 24, y: 16), withAttributes:
            [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor(rgb: palette.text)])
    }

    static func render(to directory: URL) throws {
        for dark in [false, true] {
            let view = WindowSelectionPreview(dark: dark)
            let canvas = HintCanvas(frame: view.bounds)
            canvas.screenFrame = view.bounds; canvas.desktopTop = view.bounds.height; canvas.palette = view.palette
            canvas.textFrames = view.tabs.map { CGRect(x: $0.minX + 12, y: $0.midY - 8, width: 72, height: 16) }
            let systemCanvas = Surface(id: 99, pid: 99, frame: view.bounds, layer: 21)
            var windows = WindowDiscovery.targets(surfaces: [systemCanvas] + view.surfaces, owners: [11, 22], screens: [view.bounds], deadline: Date().addingTimeInterval(1),
                currentWindow: AXUIElementCreateApplication(1)) { owner, _ in
                view.surfaces.filter { $0.pid == owner }.map {
                    .init(element: AXUIElementCreateApplication(pid_t($0.id)), frame: $0.frame, title: "Window", bundleID: "preview")
                }
            }.sorted { $0.frame.midX < $1.frame.midX }
            let labels = Hints.labels(count: windows.count + view.tabs.count)
            windows = windows.enumerated().map { index, window in
                Target(element: window.element, frame: window.frame, label: labels[index], kind: .window,
                    action: window.action, clicksMenuBarExtra: false, metadata: window.metadata)
            }
            canvas.targets = windows + view.tabs.enumerated().map { index, frame in
                Target(element: AXUIElementCreateApplication(11), frame: frame, label: labels[windows.count + index], kind: .tab,
                    action: "AXPress", clicksMenuBarExtra: false,
                    metadata: TargetMetadata(role: "AXTab", subrole: "", title: "Tab", description: "", owner: 11, bundleID: "preview"))
            }
            view.addSubview(canvas)
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw CocoaError(.coderInvalidValue) }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            guard canvas.regionMarkerFrames.count == 3, canvas.drawnLabels == Set(labels), !canvas.usesLedger,
                  !windows.contains(where: { $0.metadata.windowID == 1 }) else { throw CocoaError(.coderInvalidValue) }
            for window in windows {
                guard let marker = canvas.regionMarkerFrames[window.label],
                      window.metadata.visibleFrames!.contains(where: { view.local($0).contains(marker) }) else { throw CocoaError(.coderInvalidValue) }
            }
            for target in canvas.targets where target.kind == .tab {
                guard let marker = canvas.localBadgeFrames[target.label], view.local(target.frame).contains(marker) else { throw CocoaError(.coderInvalidValue) }
            }
            try bitmap.representation(using: .png, properties: [:])!.write(to:
                directory.appendingPathComponent("layout-window-selection-\(dark ? "dark" : "light").png"))
            let before = canvas.localBadgeFrames, colors = canvas.drawnAccents
            canvas.prefix = windows.last!.label
            view.cacheDisplay(in: view.bounds, to: bitmap)
            guard canvas.localBadgeFrames == before.filter({ $0.key.hasPrefix(canvas.prefix) }),
                  canvas.drawnAccents == colors.filter({ $0.key.hasPrefix(canvas.prefix) }) else { throw CocoaError(.coderInvalidValue) }
        }
    }
}
#endif
