#if DEBUG
import AppKit
import ApplicationServices
import OpenSesameCore

/// Unequal panels exercise the actual grouping policy and production canvas.
/// All content is synthetic; rendering never starts the controller or input taps.
final class SectionLayoutPreview: NSView {
    let palette: ThemePalette
    let controls: [Target]
    let windowFrame = CGRect(x: 24, y: 80, width: 1052, height: 560)
    var instruction = "Choose one of three regions"
    init(dark: Bool) {
        palette = ThemePalette(theme: .glitch, dark: dark)
        let sidebar = (0..<16).map { ("Item \($0 + 1)", CGRect(x: 48, y: 96 + $0 * 26, width: 140, height: 20)) }
        let toolbar = (0..<8).map { ("\($0 + 1)", CGRect(x: 316 + $0 * 72, y: 96, width: 42, height: 28)) }
        let content: [(String, CGRect)] = (0..<12).map { index in
            let x = CGFloat(316 + (index % 4) * 152)
            let y = CGFloat(226 + (index / 4) * 82)
            return ("Action \(index + 1)", CGRect(x: x, y: y, width: 116, height: 30))
        }
        let composer = (0..<8).map { ("\($0 + 1)", CGRect(x: 316 + $0 * 72, y: 562, width: 42, height: 28)) }
        controls = (sidebar + toolbar + content + composer).map { title, frame in
            Target(element: AXUIElementCreateApplication(0), frame: frame, label: "unused", kind: .control,
                   action: "AXPress", clicksMenuBarExtra: false,
                   metadata: TargetMetadata(role: "AXButton", subrole: "", title: title, description: "", owner: 0, bundleID: "preview"))
        }
        super.init(frame: CGRect(x: 0, y: 0, width: 1100, height: 700))
        appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func local(_ frame: CGRect) -> CGRect {
        CGRect(x: frame.minX, y: bounds.height - frame.maxY, width: frame.width, height: frame.height)
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(rgb: palette.background).setFill(); bounds.fill()
        NSColor(rgb: palette.surface).setFill()
        for rect in [CGRect(x: 24, y: 80, width: 216, height: 560), CGRect(x: 292, y: 80, width: 784, height: 560)] {
            NSBezierPath(roundedRect: local(rect), xRadius: 8, yRadius: 8).fill()
        }
        for control in controls {
            let rect = local(control.frame)
            NSColor(rgb: palette.text).withAlphaComponent(0.08).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
            let text = control.metadata.title as NSString
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor(rgb: palette.text)]
            let size = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: rect.minX + 8, y: rect.midY - size.height / 2), withAttributes: attributes)
        }
        (instruction as NSString).draw(at: CGPoint(x: 24, y: bounds.height - 32),
            withAttributes: [.font: NSFont.systemFont(ofSize: 16, weight: .semibold), .foregroundColor: NSColor(rgb: palette.text)])
        ("RENDERED FIXTURE · ACTUAL GROUPING + HINT CANVAS · 44 CONTROLS" as NSString).draw(at: CGPoint(x: 24, y: 20),
            withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor(rgb: palette.text)])
    }
    static func render(to directory: URL) throws {
        for dark in [false, true] {
            for size: CGFloat in [10, 16, 22] {
                let view = SectionLayoutPreview(dark: dark)
                let canvas = HintCanvas(frame: view.bounds)
                canvas.screenFrame = view.bounds; canvas.desktopTop = view.bounds.height
                canvas.fontSize = size; canvas.palette = view.palette
                var navigation = SectionNavigation()
                _ = navigation.reset(view.controls, scopedPopup: false, configuration: .standard, windowFrame: view.windowFrame)
                view.addSubview(canvas)
                guard navigation.targets.count == 3,
                      navigation.targets.flatMap(\.sectionMemberFrames).count == view.controls.count,
                      let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw CocoaError(.coderInvalidValue) }
                for level in 0..<3 {
                    canvas.targets = navigation.targets
                    canvas.scopeFrame = navigation.scopeFrame
                    canvas.canGoBack = navigation.depth > 0
                    canvas.prefersActionPanel = navigation.prefersActionPanel
                    canvas.prefix = ""
                    view.instruction = level == 0 ? "Choose one of three regions"
                        : (navigation.sectionCount > 0 ? "Narrow this region · Backspace returns to the parent" : "Choose a control · Backspace returns to the parent")
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    let colors = canvas.drawnAccents
                    let frames = canvas.localBadgeFrames
                    if navigation.sectionCount > 0 {
                        guard frames.count == navigation.sectionCount, frames.count <= 3,
                              Set(colors.values).count == frames.count,
                              colors == canvas.sectionOutlineAccents else { throw CocoaError(.coderInvalidValue) }
                    }
                    guard canvas.drawnLabels == Set(canvas.targets.map(\.label)) else { throw CocoaError(.coderInvalidValue) }
                    if navigation.sectionCount == 0 {
                        for badge in frames.values {
                            guard !view.controls.contains(where: { view.local($0.frame).intersects(badge) }) else { throw CocoaError(.coderInvalidValue) }
                        }
                    }
                    try bitmap.representation(using: .png, properties: [:])!.write(to:
                        directory.appendingPathComponent("layout-sections-level\(level + 1)-\(Int(size))-\(dark ? "dark" : "light").png"))
                    canvas.prefix = canvas.targets.last!.label
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    guard canvas.localBadgeFrames == frames.filter({ $0.key.hasPrefix(canvas.prefix) }),
                          canvas.drawnAccents == colors.filter({ $0.key.hasPrefix(canvas.prefix) }) else { throw CocoaError(.coderInvalidValue) }
                    if navigation.sectionCount == 0 { break }
                    let next = navigation.targets.max { $0.sectionMemberFrames.count < $1.sectionMemberFrames.count }!
                    guard navigation.select(next.label, configuration: .standard) else { throw CocoaError(.coderInvalidValue) }
                }
            }
        }
    }
}
#endif
