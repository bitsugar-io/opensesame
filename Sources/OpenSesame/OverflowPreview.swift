import AppKit
import ApplicationServices
import OpenSesameCore

/// Exhaustively checks real renderer pagination without starting the app,
/// installing input hooks, or interacting with live Accessibility controls.
enum OverflowPreview {
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
