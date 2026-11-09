#if DEBUG
import AppKit
import ApplicationServices
import OpenSesameCore

/// Uses the production panel with sanitized spoken group labels. Providers
/// share geometry and styling; no live browser content or actions are used.
enum TabGroupPreview {
    static func render(to directory: URL) throws {
        for dark in [false, true] {
            for size: CGFloat in [10, 16, 22] {
                var reference: CGRect?
                for provider in ["com.google.Chrome", "com.apple.Terminal"] {
                    let view = NSView(frame: CGRect(x: 0, y: 0, width: 900, height: 620))
                    let palette = ThemePalette(theme: .glitch, dark: dark)
                    view.wantsLayer = true; view.layer?.backgroundColor = NSColor(rgb: palette.surface).cgColor
                    let canvas = HintCanvas(frame: view.bounds)
                    canvas.palette = palette; canvas.fontSize = size
                    canvas.screenFrame = view.bounds; canvas.desktopTop = view.bounds.height
                    canvas.windowFrame = CGRect(x: 40, y: 70, width: 480, height: 430)
                    let rows: [(String, String)] = [
                        ("AXTabGroup", " group Hardware - 7 Tabs, • A website whose title should not replace the group name - Collapsed"),
                        ("AXTabGroup", " group Research - 1 Tab, • Accessibility documentation - Expanded"),
                        ("AXRadioButton", "Accessibility documentation"),
                        ("AXRadioButton", "Keyboard navigation — project notes"),
                        ("AXTabGroup", " group Release checklist - 12 Tabs, • A long child title, + 11 More - Collapsed"),
                        ("AXTabGroup", "Reference notes")
                    ]
                    canvas.targets = rows.enumerated().map { index, row in
                        Target(element: AXUIElementCreateApplication(0),
                            frame: CGRect(x: 90 + index * 40, y: 80, width: 8, height: 24),
                            label: ["sks", "skt", "swa", "swd", "swf", "swj"][index], kind: .tab,
                            action: "AXPress", clicksMenuBarExtra: false,
                            metadata: .init(role: row.0, subrole: "", title: row.1, description: "", owner: 0, bundleID: provider))
                    }
                    view.addSubview(canvas)
                    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw CocoaError(.coderInvalidValue) }
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    guard let panel = canvas.ledgerPanelFrame,
                          reference == nil || reference == panel,
                          canvas.drawnLabels.count == rows.count,
                          canvas.ledgerCaptions["sks"] == "Hardware",
                          canvas.ledgerGroupDetails["sks"] == "7 tabs · Collapsed",
                          canvas.ledgerGroupDetails["skt"] == "1 tab · Expanded" else { throw CocoaError(.coderInvalidValue) }
                    reference = panel
                    // Keep only a readable crop of the real panel for review.
                    let crop = CGRect(x: panel.minX - 8, y: view.bounds.height - panel.maxY - 8,
                                      width: panel.width + 16, height: panel.height + 16)
                    guard let detail = bitmap.cgImage?.cropping(to: crop) else { throw CocoaError(.coderInvalidValue) }
                    let suffix = provider == "com.google.Chrome" ? "browser" : "native"
                    try NSBitmapImageRep(cgImage: detail).representation(using: .png, properties: [:])!.write(to:
                        directory.appendingPathComponent("tab-groups-\(suffix)-\(Int(size))-\(dark ? "dark" : "light").png"))
                    let accents = canvas.drawnAccents
                    canvas.prefix = "sk"
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    guard canvas.ledgerPanelFrame == panel, canvas.drawnLabels == ["sks", "skt"],
                          canvas.drawnAccents == accents.filter({ $0.key.hasPrefix("sk") }) else { throw CocoaError(.coderInvalidValue) }
                }
            }
        }
    }
}
#endif
