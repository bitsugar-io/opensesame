import Foundation
import Testing
@testable import OpenSesameCore

@Test func everyBuiltInThemeHasReadableLightAndDarkHints() {
    func luminance(_ rgb: UInt32) -> Double {
        let channels = [16, 8, 0].map { shift -> Double in
            let value = Double((rgb >> shift) & 255) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
    }
    for theme in AppTheme.allCases {
        for dark in [true, false] {
            let p = ThemePalette(theme: theme, dark: dark)
            let background = luminance(p.background)
            for color in [p.text, p.control, p.alternate, p.tab, p.window, p.typedControl, p.typedAlternate, p.typedTab] {
                let foreground = luminance(color)
                let ratio = (max(foreground, background) + 0.05) / (min(foreground, background) + 0.05)
                #expect(ratio >= 4.5, "\(theme.rawValue) \(dark ? "dark" : "light") #\(String(color, radix: 16)) contrast \(ratio)")
            }
            #expect(Set([p.control, p.alternate, p.tab, p.window]).count == 4)
            #expect(p.control != p.typedControl && p.alternate != p.typedAlternate && p.tab != p.typedTab)
        }
    }
}
@Test func systemAppearanceFollowsMacAndOverridesStayFixed() {
    #expect(AppearanceMode.system.isDark(systemIsDark: true))
    #expect(!AppearanceMode.system.isDark(systemIsDark: false))
    #expect(!AppearanceMode.light.isDark(systemIsDark: true))
    #expect(AppearanceMode.dark.isDark(systemIsDark: false))
}
@Test func themeCustomColorsAndShortcutRoundTripTogether() throws {
    var config = AppConfiguration()
    config.theme = .custom; config.appearance = .light
    config.custom.light.control = "#AA1144"; config.custom.dark.tab = "#22EECC"
    config.shortcut = Shortcut(keyCode: 40, modifiers: ["command", "option"], key: "K")
    #expect(try AppConfiguration.parse(config.toml()) == config)
    #expect(config.shortcut.display == "⌥⌘ K")
    #expect(try config.custom.light.palette().control == 0xAA1144)
}
@Test func legacyTOMLDefaultsToGlitchSystemAndExistingHotkey() throws {
    let config = try AppConfiguration.parse("[hints]\nsize = 18\n[apps]\nmode = 'except'\nlist = ['Ghostty']")
    #expect(config.theme == .glitch && config.appearance == .system)
    #expect(config.shortcut == Shortcut())
}
@Test func invalidShortcutsAndCustomColorsAreRejected() {
    for shortcut in [Shortcut(keyCode: 49, modifiers: [], key: "Space"), Shortcut(keyCode: 0, modifiers: ["shift"], key: "A"),
                     Shortcut(keyCode: 53, modifiers: ["command"], key: "Escape"), Shortcut(keyCode: 55, modifiers: ["command"], key: "Command"),
                     Shortcut(keyCode: 20, modifiers: ["command", "shift"], key: "3"), Shortcut(keyCode: 128), Shortcut(modifiers: ["bad"])] {
        #expect(throws: (any Error).self) { try shortcut.validated() }
    }
    var custom = CustomTheme()
    custom.light.control = "red"
    #expect(throws: (any Error).self) { try custom.light.palette() }
}

@Test func themeAndShortcutTablesRejectUnknownKeysInsteadOfLosingEdits() throws {
    let source = try AppConfiguration().toml()
    for broken in [source.replacingOccurrences(of: "keyCode = 49", with: "keyCode = 49\nkeycode = 48"),
                   source.replacingOccurrences(of: "[custom.light]", with: "[custom]\nunknown = true\n[custom.light]"),
                   source.replacingOccurrences(of: "[custom.dark]", with: "[custom.dark]\ncontrlol = '#112233'")] {
        #expect(throws: (any Error).self) { try AppConfiguration.parse(broken) }
    }
}
@Test func glitchBrandColorsAreIdenticalAcrossArtworkAndThemeDefinitions() {
    #expect(ThemePalette(theme: .glitch, dark: true).control == 0xFF339C)
    #expect(ThemePalette(theme: .glitch, dark: true).tab == 0x56F5DF)
    #expect(ThemePalette(theme: .glitch, dark: false).control == 0xB21D6A)
    #expect(ThemePalette(theme: .glitch, dark: false).tab == 0x167C79)
}
