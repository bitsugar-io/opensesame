import AppKit
import OpenSesameCore

/// One original portal mark drives the menu bar, native panel, icon and README.
public enum BrandArtwork {
    private static func color(_ rgb: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255, green: CGFloat((rgb >> 8) & 255) / 255, blue: CGFloat(rgb & 255) / 255, alpha: 1)
    }
    public static let pink = color(ThemePalette(theme: .glitch, dark: true).control)
    public static let teal = color(ThemePalette(theme: .glitch, dark: true).tab)
    public static let background = NSColor(srgbRed: 0.055, green: 0.035, blue: 0.085, alpha: 1)
    public static let top = "█▀█ █▀█ █▀▀ █▄░█  █▀ █▀▀ █▀ █▀█ █▄ ▄█ █▀▀"
    public static let bottom = "█▄█ █▀▀ ██▄ █░▀█  ▄█ ██▄ ▄█ █▀█ █░▀░█ ██▄"

    private enum Segment { case move(CGFloat, CGFloat), line(CGFloat, CGFloat), curve(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat), close }
    private static let arch: [Segment] = [.move(12, 53), .line(12, 27), .curve(12, 15, 20, 8, 32, 8), .curve(44, 8, 52, 15, 52, 27), .line(52, 53)]
    private static let door: [Segment] = [.move(28, 19), .line(43, 25), .line(43, 55), .line(28, 49), .close]
    private static let sill: [Segment] = [.move(8, 55), .line(21, 55), .move(49, 55), .line(57, 55)]

    private static func path(_ segments: [Segment]) -> NSBezierPath {
        let result = NSBezierPath()
        for segment in segments {
            switch segment {
            case .move(let x, let y): result.move(to: CGPoint(x: x, y: y))
            case .line(let x, let y): result.line(to: CGPoint(x: x, y: y))
            case .curve(let a, let b, let c, let d, let x, let y): result.curve(to: CGPoint(x: x, y: y), controlPoint1: CGPoint(x: a, y: b), controlPoint2: CGPoint(x: c, y: d))
            case .close: result.close()
            }
        }
        return result
    }
    public static func draw(in rect: CGRect, template: Bool = false, primary: NSColor = pink, secondary: NSColor = teal) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let transform = NSAffineTransform()
        transform.translateX(by: rect.minX, yBy: rect.minY)
        transform.scaleX(by: rect.width / 64, yBy: rect.height / 64)
        transform.concat()
        (template ? NSColor.black : primary).setStroke()
        for segments in [arch, sill] {
            let outline = path(segments)
            outline.lineWidth = 5; outline.lineCapStyle = .round; outline.lineJoinStyle = .round
            outline.stroke()
        }
        (template ? NSColor.black : secondary).setFill()
        path(door).fill()
        if template { NSGraphicsContext.current?.compositingOperation = .destinationOut }
        (template ? NSColor.black : background).setFill()
        NSBezierPath(ovalIn: CGRect(x: 32, y: 34, width: 4, height: 4)).fill()
    }
    public static func mark(size: CGFloat = 18, template: Bool = false, primary: NSColor = pink, secondary: NSColor = teal) -> NSImage {
        let image = NSImage(size: CGSize(width: size, height: size), flipped: true) { rect in
            draw(in: rect, template: template, primary: primary, secondary: secondary); return true
        }
        image.isTemplate = template
        image.accessibilityDescription = "OpenSesame open portal"
        return image
    }
    /// Draw the same portal and block wordmark as the README SVG, without
    /// depending on font glyph substitution in the preferences header.
    public static func logo(primary: NSColor = pink, secondary: NSColor = teal, wordmark: NSColor = .secondaryLabelColor) -> NSImage {
        NSImage(size: CGSize(width: 664, height: 112), flipped: true) { _ in
            draw(in: CGRect(x: 8, y: 8, width: 96, height: 96), primary: primary, secondary: secondary)
            for (row, text) in [top, bottom].enumerated() {
                for (column, character) in text.enumerated() {
                    let spans: [(Int, Int)] = character == "█" || character == "░" ? [(0, 2)] : character == "▀" ? [(0, 1)] : character == "▄" ? [(1, 1)] : []
                    (row == 0 ? wordmark : primary).withAlphaComponent(character == "░" ? 0.25 : 1).setFill()
                    for (offset, height) in spans {
                        CGRect(x: 128 + column * 12, y: 24 + row * 32 + offset * 16, width: 12, height: height * 16).fill()
                    }
                }
            }
            return true
        }
    }
    public static func appIcon() -> NSImage {
        NSImage(size: CGSize(width: 1024, height: 1024), flipped: true) { _ in
            let tile = NSBezierPath(roundedRect: CGRect(x: 80, y: 80, width: 864, height: 864), xRadius: 192, yRadius: 192)
            NSGradient(starting: NSColor(srgbRed: 0.23, green: 0.06, blue: 0.20, alpha: 1), ending: background)?.draw(in: tile, angle: 65)
            pink.withAlphaComponent(0.28).setStroke()
            let rim = NSBezierPath(roundedRect: CGRect(x: 85, y: 85, width: 854, height: 854), xRadius: 189, yRadius: 189)
            rim.lineWidth = 3; rim.stroke()
            draw(in: CGRect(x: 205, y: 185, width: 614, height: 614))
            teal.withAlphaComponent(0.75).setFill()
            NSBezierPath(roundedRect: CGRect(x: 165, y: 343, width: 48, height: 12), xRadius: 3, yRadius: 3).fill()
            pink.setFill()
            NSBezierPath(roundedRect: CGRect(x: 798, y: 670, width: 60, height: 12), xRadius: 3, yRadius: 3).fill()
            return true
        }
    }
    public static func png(_ image: NSImage, pixels: Int) throws -> Data {
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { throw CocoaError(.coderInvalidValue) }
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
        image.draw(in: CGRect(x: 0, y: 0, width: pixels, height: pixels)); context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.coderInvalidValue) }
        return data
    }
    private static func svgPath(_ segments: [Segment]) -> String {
        segments.map {
            switch $0 {
            case .move(let x, let y): return "M\(x) \(y)"
            case .line(let x, let y): return "L\(x) \(y)"
            case .curve(let a, let b, let c, let d, let x, let y): return "C\(a) \(b) \(c) \(d) \(x) \(y)"
            case .close: return "Z"
            }
        }.joined(separator: " ")
    }
    public static func svg(dark: Bool, banner: Bool) -> String {
        let palette = ThemePalette(theme: .glitch, dark: dark)
        let primary = String(format: "#%06X", palette.control), secondary = String(format: "#%06X", palette.tab)
        var shapes = "<path d=\"\(svgPath(arch))\" fill=\"none\" stroke=\"\(primary)\" stroke-width=\"5\" stroke-linecap=\"round\"/>"
        shapes += "<path d=\"\(svgPath(sill))\" fill=\"none\" stroke=\"\(primary)\" stroke-width=\"5\" stroke-linecap=\"round\"/>"
        shapes += "<path d=\"\(svgPath(door))\" fill=\"\(secondary)\"/><circle cx=\"34\" cy=\"36\" r=\"2\" fill=\"\(dark ? "#0E0916" : "#FFFFFF")\"/>"
        if banner {
            shapes = "<g transform=\"translate(8 8) scale(1.5)\">\(shapes)</g>"
            for (row, text) in [top, bottom].enumerated() {
                for (column, c) in text.enumerated() {
                    let color = row == 0 ? (dark ? "#A38AAB" : "#77617E") : primary
                    let spans: [(Int, Int)] = c == "█" || c == "░" ? [(0, 2)] : c == "▀" ? [(0, 1)] : c == "▄" ? [(1, 1)] : []
                    for (offset, height) in spans {
                        shapes += "<rect x=\"\(128 + column * 12)\" y=\"\(24 + row * 32 + offset * 16)\" width=\"12\" height=\"\(height * 16)\" fill=\"\(color)\" opacity=\"\(c == "░" ? "0.25" : "1")\"/>"
                    }
                }
            }
        }
        return "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(banner ? "664 112" : "64 64")\" role=\"img\" aria-label=\"OpenSesame\"><title>OpenSesame</title>\(shapes)</svg>\n"
    }
}
