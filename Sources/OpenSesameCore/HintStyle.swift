import CoreGraphics

/// Shared badge metrics for the live canvas and settings samples.
/// Placement policies may move a badge, but must not shrink its typography.
public enum HintStyle {
    public static let minimumTextSize: CGFloat = 10
    public static let horizontalPadding: CGFloat = 6
    public static let verticalPadding: CGFloat = 3
    public static let cornerRadius: CGFloat = 3
    public static let borderOpacity: Double = 1
    public static let borderLineWidth: CGFloat = 1
    public static let sectionLineWidth: CGFloat = 3
    public static let sectionHaloWidth: CGFloat = 5
    public static let connectorLineWidth = sectionLineWidth

    /// Section colors identify regions rather than individual target kinds.
    /// Use the selected theme's accents in a stable spatial sequence; unique
    /// codes identify regions when colors repeat or coincide.
    public static func sectionColors(index: Int, palette: ThemePalette) -> (accent: UInt32, typed: UInt32) {
        let accents = [palette.tab, palette.window, palette.alternate, palette.control]
        return (accents[index % accents.count], palette.text)
    }

    /// Alternate only the shade within a target family's color. The index is
    /// its unfiltered ordinal within that family, so typing cannot recolor it.
    public static func colors(kind: TargetKind, index: Int, palette: ThemePalette) -> (accent: UInt32, typed: UInt32) {
        let base: UInt32, typed: UInt32
        switch kind {
        case .window: return (palette.window, palette.control)
        case .menu: base = palette.alternate; typed = palette.typedAlternate
        case .tab: base = palette.tab; typed = palette.typedTab
        case .desktop: base = palette.window; typed = palette.text
        case .control, .close: base = palette.control; typed = palette.typedControl
        }
        return (index.isMultiple(of: 2) ? base : neighboringShade(base, background: palette.background), typed)
    }

    private static func neighboringShade(_ color: UInt32, background: UInt32) -> UInt32 {
        func mix(toward white: Bool) -> UInt32 {
            [16, 8, 0].reduce(UInt32(0)) { result, shift in
                let channel = Double((color >> shift) & 0xff)
                let mixed = (channel * 0.86 + (white ? 255 : 0) * 0.14).rounded()
                return result | (UInt32(mixed) << shift)
            }
        }
        func luminance(_ value: UInt32) -> Double {
            let channels = [16, 8, 0].map { shift -> Double in
                let channel = Double((value >> shift) & 0xff) / 255
                return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
            }
            return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
        }
        let surface = luminance(background)
        func contrast(_ value: UInt32) -> Double {
            let ink = luminance(value)
            return (max(ink, surface) + 0.05) / (min(ink, surface) + 0.05)
        }
        // Mixing with white or black preserves hue. Choose the direction that
        // improves contrast for the actual background, including custom themes.
        let lighter = mix(toward: true), darker = mix(toward: false)
        return contrast(lighter) >= contrast(darker) ? lighter : darker
    }

    public static func badgeSize(text: CGSize) -> CGSize {
        CGSize(width: ceil(text.width) + horizontalPadding * 2,
               height: ceil(text.height) + verticalPadding * 2)
    }
}
