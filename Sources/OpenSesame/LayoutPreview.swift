import AppKit
import ApplicationServices
import OpenSesameCore
import OpenSesameBrand

// Synthetic controls, real HintCanvas. No AX queries or input events.
final class LayoutPreview: NSView {
    override func draw(_ dirtyRect: NSRect) {
        BrandArtwork.background.setFill(); bounds.fill()
        func text(_ value: String, _ x: CGFloat, _ y: CGFloat, size: CGFloat = 14, color: NSColor = .white) {
            (value as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .medium), .foregroundColor: color])
        }
        text("COMPACT CONTROLS / RENDERED PREVIEW", 28, 355, size: 11, color: BrandArtwork.teal)
        NSColor(white: 0.12, alpha: 1).setFill()
        NSBezierPath(roundedRect: CGRect(x: 70, y: 120, width: 500, height: 200), xRadius: 16, yRadius: 16).fill()
        text("Keep awake", 95, 276, size: 20)
        text("Choose a duration", 95, 244, size: 12, color: .lightGray)
        for (index, value) in ["15m", "30m", "45m", "1h", "4h", "8h"].enumerated() {
            let x = CGFloat(110 + index * 72)
            NSColor(white: 0.23, alpha: 1).setFill()
            NSBezierPath(roundedRect: CGRect(x: x, y: 200, width: 44, height: 28), xRadius: 6, yRadius: 6).fill()
            text(value, x + 8, 207, size: 12)
        }
        text("Labels stay close to the controls they activate.", 95, 138, size: 12, color: .lightGray)
        text("Actual hint renderer • synthetic UI • no app interaction", 28, 28, size: 11, color: .lightGray)
    }
    static func render(to directory: URL) throws {
        let view = LayoutPreview(frame: CGRect(x: 0, y: 0, width: 640, height: 400))
        let canvas = HintCanvas(frame: view.bounds)
        canvas.screenFrame = view.bounds; canvas.desktopTop = view.bounds.height
        canvas.scopeFrame = CGRect(x: 70, y: 80, width: 500, height: 200)
        canvas.textFrames = [CGRect(x: 95, y: 244, width: 360, height: 18)]
        canvas.targets = (0..<6).map { index in
            Target(element: AXUIElementCreateApplication(0), frame: CGRect(x: 110 + index * 72, y: 172, width: 44, height: 28),
                   label: ["as", "ad", "af", "ag", "ah", "aj"][index], kind: .control, action: "AXPress", clicksMenuBarExtra: false,
                   metadata: TargetMetadata(role: "AXButton", subrole: "", title: "", description: "", owner: 0, bundleID: "preview"))
        }
        view.addSubview(canvas)
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw CocoaError(.coderInvalidValue) }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("compact-controls.png"))
    }
}
