#if DEBUG
import AppKit
import OpenSesameBrand
import OpenSesameCore

/// Inspect the original artwork and the full hint alphabet with the production
/// block renderer. This reference sheet is never part of the app's UI.
final class BlockLetteringPreview: NSView {
    let palette: ThemePalette
    init(dark: Bool) {
        palette = ThemePalette(theme: .glitch, dark: dark)
        super.init(frame: CGRect(x: 0, y: 0, width: 1000, height: 800))
        appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func draw(_ dirtyRect: NSRect) {
        let background = NSColor(rgb: palette.background), accent = NSColor(rgb: palette.tab), text = NSColor(rgb: palette.text)
        background.setFill(); bounds.fill()
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: text]
        ("Existing OpenSesame wordmark" as NSString).draw(at: CGPoint(x: 24, y: 768), withAttributes: attributes)
        BrandArtwork.logo(primary: NSColor(rgb: palette.control), secondary: accent, wordmark: text)
            .draw(in: CGRect(x: 24, y: 640, width: 664, height: 112))
        ("Same block grid · original seven glyphs preserved · full configured alphabet supported" as NSString)
            .draw(at: CGPoint(x: 24, y: 608), withAttributes: attributes)
        for (index, letter) in "ABCDEFGHIJKLMNOPQRSTUVWXYZ".enumerated() {
            let code = String(letter), width = BlockLettering.aspectRatio(for: code) * 64
            let center = CGPoint(x: 88 + CGFloat(index % 7) * 136, y: 536 - CGFloat(index / 7) * 136)
            BlockLettering.draw(code, in: CGRect(x: center.x - width / 2, y: center.y - 32, width: width, height: 64),
                accent: accent, typed: text, prefixLength: 0, background: background)
            let size = (code as NSString).size(withAttributes: attributes)
            (code as NSString).draw(at: CGPoint(x: center.x - size.width / 2, y: center.y - 60), withAttributes: attributes)
        }
        ("RENDERED REFERENCE · ACTUAL BRAND ARTWORK + BLOCK LETTERING" as NSString)
            .draw(at: CGPoint(x: 24, y: 20), withAttributes: attributes)
    }
    static func render(to directory: URL) throws {
        for dark in [false, true] {
            let view = BlockLetteringPreview(dark: dark)
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw CocoaError(.coderInvalidValue) }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to:
                directory.appendingPathComponent("block-lettering-\(dark ? "dark" : "light").png"))
        }
    }
}
#endif
