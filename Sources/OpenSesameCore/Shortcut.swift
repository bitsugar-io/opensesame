import Foundation

public struct Shortcut: Equatable, Decodable {
    public var keyCode: Int
    public var modifiers: [String]
    public var key: String
    public init(keyCode: Int = 49, modifiers: [String] = ["control", "shift"], key: String = "Space") {
        self.keyCode = keyCode; self.modifiers = modifiers; self.key = key
    }
    enum CodingKeys: String, CodingKey { case keyCode, modifiers, key }
    public init(from decoder: Decoder) throws {
        try checkKeys(decoder, allowed: ["keyCode", "modifiers", "key"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        keyCode = try c.decode(Int.self, forKey: .keyCode)
        modifiers = try c.decode([String].self, forKey: .modifiers)
        key = try c.decode(String.self, forKey: .key)
    }
    public var display: String {
        ["control", "option", "shift", "command"].compactMap { name in
            modifiers.contains(name) ? ["control": "⌃", "option": "⌥", "shift": "⇧", "command": "⌘"][name] : nil
        }.joined() + " " + key
    }
    public func validated() throws -> Self {
        let allowed: Set<String> = ["control", "option", "shift", "command"]
        guard (0...127).contains(keyCode), ![53,54,55,56,57,58,59,60,61,62,63].contains(keyCode),
              Set(modifiers).isSubset(of: allowed), Set(modifiers).count == modifiers.count,
              !Set(modifiers).intersection(["control", "option", "command"]).isEmpty,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, key.count <= 24 else {
            throw ConfigurationError.invalid("Shortcut requires Command, Control, or Option plus a non-modifier key.")
        }
        // Keep system screenshot commands available while hints are displayed.
        guard !(keyCode == 20 && modifiers.contains("command") && modifiers.contains("shift") && !modifiers.contains("option")) else {
            throw ConfigurationError.invalid("Command–Shift–3 is reserved for screenshots.")
        }
        return self
    }
}
