import Foundation
import Testing
@testable import OpenSesameCore

@Test func tabAndWindowColorsKeepTheirMeaningInOverflow() {
    var palette = ThemePalette(theme: .glitch, dark: true)
    palette.typedTab = 0x123456
    for index in [0, 1, 40] {
        let tab = HintStyle.colors(kind: .tab, index: index, palette: palette)
        if index.isMultiple(of: 2) { #expect(tab.accent == palette.tab) }
        #expect(tab.typed == palette.typedTab)
        #expect(HintStyle.colors(kind: .window, index: index, palette: palette).accent == palette.window)
    }
}

@Test func compactTagsStayInTheirColorFamilyWithReadableNeighboringShades() {
    func channels(_ color: UInt32) -> [Double] {
        [16, 8, 0].map { Double((color >> $0) & 0xff) / 255 }
    }
    func luminance(_ color: UInt32) -> Double {
        let linear = channels(color).map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return zip(linear, [0.2126, 0.7152, 0.0722]).reduce(0) { $0 + $1.0 * $1.1 }
    }
    func contrast(_ ink: UInt32, _ background: UInt32) -> Double {
        let a = luminance(ink), b = luminance(background)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
    // Removing each color's minimum and scaling its range compares hue
    // independently of tint/shade. The old pink/purple alternation fails this.
    func hueChannels(_ color: UInt32) -> [Double] {
        let rgb = channels(color), low = rgb.min()!, range = rgb.max()! - rgb.min()!
        return rgb.map { ($0 - low) / max(range, 0.001) }
    }
    for theme in AppTheme.allCases {
        for dark in [false, true] {
            let palette = ThemePalette(theme: theme, dark: dark)
            for (kind, base, typed) in [(TargetKind.menu, palette.alternate, palette.typedAlternate),
                                        (.tab, palette.tab, palette.typedTab), (.control, palette.control, palette.typedControl)] {
                let first = HintStyle.colors(kind: kind, index: 0, palette: palette)
                let second = HintStyle.colors(kind: kind, index: 1, palette: palette)
                #expect(first.accent == base && second.accent != first.accent)
                #expect(first.typed == typed && second.typed == typed)
                #expect(zip(hueChannels(base), hueChannels(second.accent)).allSatisfy { abs($0 - $1) < 0.02 })
                #expect(contrast(first.accent, palette.background) >= 4.5)
                #expect(contrast(second.accent, palette.background) >= contrast(first.accent, palette.background))
            }
        }
    }
}

@Test func sectionsUseFourThemeAccentsInBothAppearances() {
    for theme in AppTheme.allCases {
        for dark in [false, true] {
            let palette = ThemePalette(theme: theme, dark: dark)
            let accents = (0..<4).map { HintStyle.sectionColors(index: $0, palette: palette).accent }
            #expect(Set(accents).count == 4)
            #expect(Set(accents) == Set([palette.control, palette.alternate, palette.tab, palette.window]))
        }
    }
}
