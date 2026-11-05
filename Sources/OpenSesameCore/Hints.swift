public enum Hints {
    public static let alphabet = Array("asdfghjklqwertyuiopzxcvbnm")
    public static func matches(prefix: String, labels: [String]) -> [String] {
        labels.filter { $0.hasPrefix(prefix) }
    }
    public static func letter(_ text: String) -> String? {
        let normalized = text.lowercased()
        guard normalized.count == 1, let character = normalized.first,
              alphabet.contains(character) else { return nil }
        return normalized
    }
    public static func inputCharacter(_ text: String) -> String? {
        if let letter = letter(text) { return letter }
        return text.count == 1 && "0123456789".contains(text) ? text : nil
    }
    // Equal length codes prevent a short hint from being a prefix of another.
    public static func labels(count: Int, configuration: HintConfiguration = .standard) -> [String] {
        guard count > 0 else { return [] }
        let alphabet = Array(configuration.alphabet)
        var width = configuration.minimumLength
        var capacity = 1
        for _ in 0..<width { capacity *= alphabet.count }
        while capacity < count {
            width += 1
            let next = capacity.multipliedReportingOverflow(by: alphabet.count)
            capacity = next.overflow ? count : next.partialValue
        }
        return (0..<count).map { index in
            var value = index
            var letters = Array(repeating: alphabet[0], count: width)
            for offset in (0..<width).reversed() {
                letters[offset] = alphabet[value % alphabet.count]
                value /= alphabet.count
            }
            return configuration.prefix + String(letters)
        }
    }
    public static func allows(bundleID: String, name: String, list: [String], only: Bool) -> Bool {
        let matches = list.contains { $0.caseInsensitiveCompare(bundleID) == .orderedSame || $0.caseInsensitiveCompare(name) == .orderedSame }
        return only ? matches : !matches
    }
}
import Foundation
