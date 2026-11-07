import AppKit

/// A readable monospaced companion to the large wordmark-derived block codes.
/// Use this exact font for drawing, measuring, overflow, and settings samples.
public enum HintTypography {
    public static func compactCode(size: CGFloat) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: size, weight: .semibold)
    }
}
