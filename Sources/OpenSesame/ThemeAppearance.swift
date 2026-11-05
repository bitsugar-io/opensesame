import AppKit
import SwiftUI
import OpenSesameCore

extension NSColor {
    convenience init(rgb: UInt32) {
        self.init(srgbRed: CGFloat((rgb >> 16) & 255) / 255, green: CGFloat((rgb >> 8) & 255) / 255,
                  blue: CGFloat(rgb & 255) / 255, alpha: 1)
    }
    var hexRGB: String {
        let c = usingColorSpace(.sRGB) ?? self
        return String(format: "#%02X%02X%02X", Int((c.redComponent * 255).rounded()), Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
    }
}
extension Controller {
    var resolvedPalette: ThemePalette {
        let dark = appearanceMode.isDark(systemIsDark: NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
        return palette(dark: dark)
    }
    func palette(dark: Bool) -> ThemePalette {
        if theme == .custom, let palette = try? (dark ? customTheme.dark : customTheme.light).palette() { return palette }
        return ThemePalette(theme: theme, dark: dark)
    }
    func refreshAppearance() { onAppearanceChange?(); redrawForAppearance() }
}
