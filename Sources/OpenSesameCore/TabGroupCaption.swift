import Foundation

/// Presentation only: a provider's spoken label must never choose an action.
public struct TabGroupCaption: Equatable {
    public let title: String
    public let detail: String

    public init(_ label: String) {
        let raw = label.trimmingCharacters(in: .whitespacesAndNewlines)
        var summary = raw
        let state = ["Collapsed", "Expanded"].first { summary.hasSuffix(" - " + $0) }
        if let state { summary.removeLast(state.count + 3) }
        if let children = summary.range(of: ", • ") { summary = String(summary[..<children.lowerBound]) }
        // Recognize the observed spoken summary only in its complete form.
        // Unknown/localized labels retain their full text instead of guessing.
        let pattern = #"^group (.+) - ([0-9]+) Tabs?$"#
        if let expression = try? NSRegularExpression(pattern: pattern),
           let match = expression.firstMatch(in: summary, range: NSRange(summary.startIndex..., in: summary)),
           let nameRange = Range(match.range(at: 1), in: summary),
           let countRange = Range(match.range(at: 2), in: summary),
           let count = Int(summary[countRange]) {
            title = String(summary[nameRange])
            detail = "\(count) \(count == 1 ? "tab" : "tabs")" + (state.map { " · " + $0 } ?? "")
        } else {
            title = raw.isEmpty ? "Tab group" : raw
            detail = "Tab group"
        }
    }
}
