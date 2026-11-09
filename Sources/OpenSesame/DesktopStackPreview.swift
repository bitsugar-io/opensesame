#if DEBUG
import AppKit
import ApplicationServices
import OpenSesameCore

/// Synthetic desktop states rendered by the production canvas. This verifies
/// corner placement and ownership, not Finder's live Accessibility support.
final class DesktopStackPreview: NSView {
    let palette: ThemePalette
    let expanded: Bool
    let stackFrame = CGRect(x: 1000, y: 70, width: 80, height: 72)
    let fileFrames = [CGRect(x: 880, y: 210, width: 80, height: 72), CGRect(x: 1000, y: 210, width: 80, height: 72)]
    init(dark: Bool, expanded: Bool) {
        self.expanded = expanded; palette = ThemePalette(theme: .glitch, dark: dark)
        super.init(frame: CGRect(x: 0, y: 0, width: 1140, height: 500))
        appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func local(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: bounds.height - rect.maxY, width: rect.width, height: rect.height)
    }
    private func text(_ value: String, at point: CGPoint, size: CGFloat = 13) {
        (value as NSString).draw(at: point, withAttributes: [.font: NSFont.systemFont(ofSize: size), .foregroundColor: NSColor(rgb: palette.text)])
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(rgb: palette.background).setFill(); bounds.fill()
        NSColor(rgb: palette.surface).setFill()
        NSBezierPath(roundedRect: CGRect(x: 28, y: 70, width: 700, height: 360), xRadius: 8, yRadius: 8).fill()
        text("Current window", at: CGPoint(x: 48, y: 400))
        text(expanded ? "Expanded desktop stack" : "Collapsed desktop stack", at: CGPoint(x: 28, y: 464), size: 16)
        let items = [(stackFrame, "Screenshots")] + (expanded ? fileFrames.enumerated().map { ($0.element, "Capture \($0.offset + 1)") } : [])
        for (rect, title) in items {
            NSColor(rgb: palette.window).withAlphaComponent(0.12).setFill()
            NSBezierPath(roundedRect: local(rect), xRadius: 5, yRadius: 5).fill()
            let symbol = title == "Screenshots" ? "square.stack.3d.up" : "photo"
            NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(.init(paletteColors: [NSColor(rgb: palette.text)]))?
                .draw(in: local(rect).insetBy(dx: 24, dy: 20))
            text(title, at: CGPoint(x: rect.minX - 2, y: local(rect).minY - 22), size: 12)
        }
        text("RENDERED FIXTURE · ACTUAL HINT CANVAS · SYNTHETIC DESKTOP", at: CGPoint(x: 28, y: 20), size: 10)
    }
    static func render(to directory: URL) throws {
        for dark in [false, true] {
            for expanded in [false, true] {
                let view = DesktopStackPreview(dark: dark, expanded: expanded)
                let canvas = HintCanvas(frame: view.bounds)
                canvas.palette = view.palette; canvas.screenFrame = view.bounds; canvas.desktopTop = view.bounds.height
                let frames = [view.stackFrame] + (expanded ? view.fileFrames : [])
                canvas.targets = zip(frames, Hints.labels(count: frames.count)).enumerated().map { index, item in
                    Target(element: AXUIElementCreateApplication(0), frame: item.0, label: item.1, kind: .desktop,
                        action: index == 0 ? AccessibilityActionPolicy.togglePrefix + "AXExpanded" : "AXOpen", clicksMenuBarExtra: false,
                        metadata: .init(role: index == 0 ? "AXGroup" : "AXImage", subrole: "", title: index == 0 ? "Screenshots" : "Capture \(index)",
                            description: "", owner: 0, bundleID: "com.apple.finder", isDisclosure: index == 0))
                }
                view.addSubview(canvas)
                guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw CocoaError(.coderInvalidValue) }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard !canvas.usesLedger, canvas.associatedLabels.isEmpty, canvas.drawnLabels.count == frames.count,
                      canvas.targets.allSatisfy({ target in canvas.localBadgeFrames[target.label].map { view.local(target.frame).contains($0) } == true }) else { throw CocoaError(.coderInvalidValue) }
                try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(
                    "desktop-stack-\(expanded ? "expanded" : "collapsed")-\(dark ? "dark" : "light").png"))
            }
        }
    }
}
#endif
