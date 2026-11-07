import Foundation
import TOMLDecoder

public struct AppConfiguration: Equatable, Decodable {
    public var custom = CustomTheme()
    public var shortcut = Shortcut()
    public var stacksShortcut = Shortcut.stacks
    public var saveStackShortcut = Shortcut.saveStack
    public var stacks: StacksConfiguration?
    public var theme: AppTheme = .glitch
    public var appearance: AppearanceMode = .system
    public var hints = HintSettings()
    public var apps = AppSettings()
    public var icons = IconSettings()
    public init() {}
    public struct IconSettings: Equatable, Decodable {
        public var chrome = false
        public init() {}
        enum CodingKeys: String, CodingKey { case chrome }
        public init(from decoder: Decoder) throws {
            try checkKeys(decoder, allowed: ["chrome"])
            let c = try decoder.container(keyedBy: CodingKeys.self)
            chrome = try c.decodeIfPresent(Bool.self, forKey: .chrome) ?? false
        }
    }
    public struct HintSettings: Equatable, Decodable {
        public var size: Double = 16
        public var menuBar = true
        public var minimumLength = 2
        public var alphabet = HintConfiguration.defaultAlphabet
        public var prefix = ""
        public init() {}
        enum CodingKeys: String, CodingKey { case size, menuBar = "menu_bar", minimumLength = "minimum_length", alphabet, prefix }
        public init(from decoder: Decoder) throws {
            try checkKeys(decoder, allowed: ["size", "menu_bar", "minimum_length", "alphabet", "prefix"])
            let c = try decoder.container(keyedBy: CodingKeys.self)
            size = try c.decodeIfPresent(Double.self, forKey: .size) ?? 16
            menuBar = try c.decodeIfPresent(Bool.self, forKey: .menuBar) ?? true
            minimumLength = try c.decodeIfPresent(Int.self, forKey: .minimumLength) ?? 2
            alphabet = try c.decodeIfPresent(String.self, forKey: .alphabet) ?? HintConfiguration.defaultAlphabet
            prefix = try c.decodeIfPresent(String.self, forKey: .prefix) ?? ""
        }
    }
    public struct AppSettings: Equatable, Decodable {
        public enum Mode: String, Decodable { case only, except }
        public var mode: Mode = .except
        public var list: [String] = []
        public init() {}
        enum CodingKeys: String, CodingKey { case mode, list }
        public init(from decoder: Decoder) throws {
            try checkKeys(decoder, allowed: ["mode", "list"])
            let c = try decoder.container(keyedBy: CodingKeys.self)
            mode = try c.decodeIfPresent(Mode.self, forKey: .mode) ?? .except
            list = try c.decodeIfPresent([String].self, forKey: .list) ?? []
        }
    }
    enum CodingKeys: String, CodingKey { case hints, apps, icons, shortcut, theme, appearance, custom, stacks; case stacksShortcut = "stacks_shortcut", saveStackShortcut = "save_stack_shortcut" }
    public init(from decoder: Decoder) throws {
        try checkKeys(decoder, allowed: ["hints", "apps", "icons", "shortcut", "stacks_shortcut", "save_stack_shortcut", "stacks", "theme", "appearance", "custom"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        custom = try c.decodeIfPresent(CustomTheme.self, forKey: .custom) ?? CustomTheme()
        shortcut = try c.decodeIfPresent(Shortcut.self, forKey: .shortcut) ?? Shortcut()
        if let saved = try c.decodeIfPresent(Shortcut.self, forKey: .stacksShortcut) {
            stacksShortcut = saved
        } else {
            // Preserve an older file whose custom hints shortcut already uses
            // the new default. Explicit duplicate bindings still fail validation.
            stacksShortcut = shortcut.hasSameBinding(as: .stacks)
                ? Shortcut(keyCode: 49, modifiers: ["control", "option", "shift"], key: "Space") : .stacks
        }
        theme = try c.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .glitch
        if let saved = try c.decodeIfPresent(Shortcut.self, forKey: .saveStackShortcut) {
            saveStackShortcut = saved
        } else {
            // At most two existing bindings can occupy these three defaults.
            saveStackShortcut = [Shortcut.saveStack,
                Shortcut(keyCode: 36, modifiers: ["control", "option", "shift"], key: "Return"),
                Shortcut(keyCode: 36, modifiers: ["control", "option", "command"], key: "Return")]
                .first { !$0.hasSameBinding(as: shortcut) && !$0.hasSameBinding(as: stacksShortcut) }!
        }
        appearance = try c.decodeIfPresent(AppearanceMode.self, forKey: .appearance) ?? .system
        hints = try c.decodeIfPresent(HintSettings.self, forKey: .hints) ?? HintSettings()
        apps = try c.decodeIfPresent(AppSettings.self, forKey: .apps) ?? AppSettings()
        icons = try c.decodeIfPresent(IconSettings.self, forKey: .icons) ?? IconSettings()
        stacks = try c.decodeIfPresent(StacksConfiguration.self, forKey: .stacks)
    }
    public static func parse(_ source: String) throws -> Self {
        var config = try TOMLDecoder().decode(Self.self, from: source)
        guard config.hints.size.isFinite, (10...22).contains(config.hints.size), config.hints.size.rounded() == config.hints.size else {
            throw ConfigurationError.invalid("hints.size must be a whole number from 10 to 22.")
        }
        _ = try config.shortcut.validated()
        _ = try config.stacksShortcut.validated()
        _ = try config.saveStackShortcut.validated()
        guard !config.shortcut.hasSameBinding(as: config.stacksShortcut),
              !config.saveStackShortcut.hasSameBinding(as: config.shortcut),
              !config.saveStackShortcut.hasSameBinding(as: config.stacksShortcut) else {
            throw ConfigurationError.invalid("Hints, show stacks, and save stack must use different shortcuts.")
        }
        _ = try config.custom.light.palette()
        _ = try config.custom.dark.palette()
        let codes = try HintConfiguration(minimumLength: config.hints.minimumLength, alphabet: config.hints.alphabet, prefix: config.hints.prefix)
        config.hints.alphabet = codes.alphabet; config.hints.prefix = codes.prefix
        guard config.apps.list.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw ConfigurationError.invalid("apps.list cannot contain empty names.")
        }
        return config
    }
    public func toml() throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.withoutEscapingSlashes]
        func quoted(_ text: String) throws -> String { String(decoding: try encoder.encode(text), as: UTF8.self) }
        return """
        # OpenSesame — edit, save, then choose Reload in the menu bar.
        theme = "\(theme.rawValue)"
        appearance = "\(appearance.rawValue)"

        [shortcut]
        keyCode = \(shortcut.keyCode)
        modifiers = [\(try shortcut.modifiers.map { try quoted($0) }.joined(separator: ", "))]
        key = \(try quoted(shortcut.key))

        [stacks_shortcut]
        keyCode = \(stacksShortcut.keyCode)
        modifiers = [\(try stacksShortcut.modifiers.map { try quoted($0) }.joined(separator: ", "))]
        key = \(try quoted(stacksShortcut.key))

        [save_stack_shortcut]
        keyCode = \(saveStackShortcut.keyCode)
        modifiers = [\(try saveStackShortcut.modifiers.map { try quoted($0) }.joined(separator: ", "))]
        key = \(try quoted(saveStackShortcut.key))

        [hints]
        size = \(Int(hints.size))
        menu_bar = \(hints.menuBar)
        minimum_length = \(hints.minimumLength)
        alphabet = \(try quoted(hints.alphabet))
        prefix = \(try quoted(hints.prefix))

        # Use "only" for an allowlist, or "except" for exclusions.
        [apps]
        mode = "\(apps.mode.rawValue)"
        list = [\(try apps.list.map { try quoted($0) }.joined(separator: ", "))]

        # Optional local website icons; requires Chrome Automation access.
        [icons]
        chrome = \(icons.chrome)

        \(custom.light.toml(section: "light"))

        \(custom.dark.toml(section: "dark"))

        \(try stacks?.toml() ?? "")

        """
    }
    public static func location(environment: [String: String] = ProcessInfo.processInfo.environment, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        let base = environment["XDG_CONFIG_HOME"].flatMap { $0.hasPrefix("/") ? URL(fileURLWithPath: $0) : nil }
            ?? home.appendingPathComponent(".config")
        return base.appendingPathComponent("opensesame/config.toml")
    }
}
public enum ConfigurationError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { switch self { case .invalid(let message): return message } }
}
private struct ConfigurationKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}
func checkKeys(_ decoder: Decoder, allowed: Set<String>) throws {
    let c = try decoder.container(keyedBy: ConfigurationKey.self)
    let unknown = Set(c.allKeys.map(\.stringValue)).subtracting(allowed)
    guard unknown.isEmpty else { throw ConfigurationError.invalid("Unknown configuration keys: \(unknown.sorted().joined(separator: ", ")).") }
}
