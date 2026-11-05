import Foundation

public struct CustomTheme: Equatable, Decodable {
    public var light: Colors
    public var dark: Colors
    public init() { light = Colors(dark: false); dark = Colors(dark: true) }
    enum CodingKeys: String, CodingKey { case light, dark }
    public init(from decoder: Decoder) throws {
        try checkKeys(decoder, allowed: ["light", "dark"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        light = try c.decode(Colors.self, forKey: .light); dark = try c.decode(Colors.self, forKey: .dark)
    }
    public struct Colors: Equatable, Decodable {
        public var background: String, surface: String, text: String
        public var control: String, alternate: String, tab: String, window: String
        public init(dark: Bool) {
            let p = ThemePalette(theme: .glitch, dark: dark)
            func hex(_ value: UInt32) -> String { String(format: "#%06X", value) }
            background = hex(p.background); surface = hex(p.surface); text = hex(p.text)
            control = hex(p.control); alternate = hex(p.alternate); tab = hex(p.tab); window = hex(p.window)
        }
        enum CodingKeys: String, CodingKey { case background, surface, text, control, alternate, tab, window }
        public init(from decoder: Decoder) throws {
            try checkKeys(decoder, allowed: ["background", "surface", "text", "control", "alternate", "tab", "window"])
            let c = try decoder.container(keyedBy: CodingKeys.self)
            background = try c.decode(String.self, forKey: .background); surface = try c.decode(String.self, forKey: .surface)
            text = try c.decode(String.self, forKey: .text); control = try c.decode(String.self, forKey: .control)
            alternate = try c.decode(String.self, forKey: .alternate); tab = try c.decode(String.self, forKey: .tab)
            window = try c.decode(String.self, forKey: .window)
        }
        public func palette() throws -> ThemePalette {
            func rgb(_ value: String) throws -> UInt32 {
                guard value.count == 7, value.first == "#", let result = UInt32(value.dropFirst(), radix: 16) else {
                    throw ConfigurationError.invalid("Custom colors must use #RRGGBB.")
                }
                return result
            }
            var p = ThemePalette(theme: .glitch, dark: true)
            p.background = try rgb(background); p.surface = try rgb(surface); p.text = try rgb(text)
            p.control = try rgb(control); p.alternate = try rgb(alternate); p.tab = try rgb(tab); p.window = try rgb(window)
            p.typedControl = p.window; p.typedAlternate = p.tab; p.typedTab = p.control
            return p
        }
        public func toml(section: String) -> String {
            """
            [custom.\(section)]
            background = "\(background)"
            surface = "\(surface)"
            text = "\(text)"
            control = "\(control)"
            alternate = "\(alternate)"
            tab = "\(tab)"
            window = "\(window)"
            """
        }
    }
}
