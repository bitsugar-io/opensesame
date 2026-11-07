import AppKit
import OpenSesameCore

/// Compact annotations stay light; spatial selections keep a stronger outline.
/// Keep the full colored stroke inside the bounds so clipping a window's
/// exposed area cannot halve the thickness of its outside edges.
public enum HintBorder {
    public enum Kind { case compact, region }

    public static func draw(in rect: CGRect, kind: Kind, cornerRadius: CGFloat = 6, accent: NSColor, background: NSColor) {
        let width = kind == .compact ? HintStyle.borderLineWidth : HintStyle.sectionLineWidth
        let inset = width / 2
        let outline = NSBezierPath(roundedRect: rect.insetBy(dx: inset, dy: inset), xRadius: cornerRadius, yRadius: cornerRadius)
        if kind == .region {
            background.withAlphaComponent(0.9).setStroke()
            outline.lineWidth = HintStyle.sectionHaloWidth; outline.stroke()
        }
        accent.setStroke()
        outline.lineWidth = width; outline.stroke()
    }
}
