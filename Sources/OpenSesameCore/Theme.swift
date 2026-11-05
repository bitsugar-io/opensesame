import Foundation

public enum AppTheme: String, CaseIterable, Decodable {
    case glitch, catppuccin, tokyoNight = "tokyo-night", gruvbox, dracula, custom
    public var title: String { self == .tokyoNight ? "Tokyo Night" : rawValue.capitalized }
}
public enum AppearanceMode: String, CaseIterable, Decodable {
    case system, light, dark
    public func isDark(systemIsDark: Bool) -> Bool { self == .system ? systemIsDark : self == .dark }
}
public struct ThemePalette: Equatable {
    public var background: UInt32, surface: UInt32, text: UInt32
    public var control: UInt32, alternate: UInt32, tab: UInt32, window: UInt32
    public var typedControl: UInt32, typedAlternate: UInt32, typedTab: UInt32
    public init(theme: AppTheme, dark: Bool) {
        let colors: [UInt32]
        switch (theme, dark) {
        case (.glitch, true), (.custom, true): colors = [0x0e0916,0x211827,0xf7f2fc,0xff339c,0xc994ff,0x56f5df,0xffd65c]
        case (.glitch, false), (.custom, false): colors = [0xfaf5fc,0xf0e7f3,0x24152f,0xb21d6a,0x6530a0,0x167c79,0x805100]
        case (.catppuccin, true): colors = [0x1e1e2e,0x313244,0xcdd6f4,0xf5c2e7,0xcba6f7,0x94e2d5,0xf9e2af]
        case (.catppuccin, false): colors = [0xeff1f5,0xe6e9ef,0x4c4f69,0xa42e74,0x8839ef,0x146d65,0x856000]
        case (.tokyoNight, true): colors = [0x1a1b26,0x24283b,0xc0caf5,0x7aa2f7,0xbb9af7,0x73daca,0xe0af68]
        case (.tokyoNight, false): colors = [0xe1e2e7,0xd5d6db,0x343b58,0x2958a8,0x78459b,0x00685d,0x775000]
        case (.gruvbox, true): colors = [0x282828,0x3c3836,0xebdbb2,0xfb9690,0xd8a0bd,0x8ec07c,0xfabd2f]
        case (.gruvbox, false): colors = [0xfbf1c7,0xebdbb2,0x3c3836,0x9d0006,0x8f3f71,0x3e7352,0x825500]
        case (.dracula, true): colors = [0x282a36,0x343746,0xf8f8f2,0xff79c6,0xbd93f9,0x8be9fd,0xf1fa8c]
        case (.dracula, false): colors = [0xf8f5fc,0xeee8f5,0x282a36,0xa6216d,0x7040a0,0x006575,0x6d6000]
        }
        background = colors[0]; surface = colors[1]; text = colors[2]
        control = colors[3]; alternate = colors[4]; tab = colors[5]; window = colors[6]
        typedControl = colors[6]; typedAlternate = colors[5]; typedTab = colors[3]
    }
}
