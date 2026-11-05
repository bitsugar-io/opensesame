import Foundation

/// Popup rows use a shared letter; numbers identify enabled controls left to right.
public enum LedgerLayout {
    public static func rows(frames: [CGRect]) -> [[Int]] {
        var rows: [[Int]] = []
        for index in frames.indices.sorted(by: {
            frames[$0].minY == frames[$1].minY ? (frames[$0].minX == frames[$1].minX ? $0 < $1 : frames[$0].minX < frames[$1].minX) : frames[$0].minY < frames[$1].minY
        }) {
            if let last = rows.last, let first = last.first, abs(frames[first].minY - frames[index].minY) <= 8 {
                rows[rows.count - 1].append(index)
            } else { rows.append([index]) }
        }
        return rows.map { row in row.sorted { frames[$0].minX == frames[$1].minX ? $0 < $1 : frames[$0].minX < frames[$1].minX } }
    }
    public static func labels(frames: [CGRect], configuration: HintConfiguration = .standard) -> [String] {
        let groups = rows(frames: frames)
        let digits = String(groups.map(\.count).max() ?? 1).count
        let rowConfiguration = try! HintConfiguration(minimumLength: max(1, configuration.minimumLength - digits), alphabet: configuration.alphabet, prefix: configuration.prefix)
        let rowLabels = Hints.labels(count: groups.count, configuration: rowConfiguration)
        var result = Array(repeating: "", count: frames.count)
        for (row, indices) in groups.enumerated() {
            for (column, index) in indices.enumerated() {
                let number = String(column + 1)
                result[index] = rowLabels[row] + String(repeating: "0", count: digits - number.count) + number
            }
        }
        return result
    }
}
