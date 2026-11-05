import CoreGraphics

/// Spatial sections keep a crowded window navigable without dropping actions.
/// Splits use control centers, so a wide container cannot swallow nearby items.
public enum HintSections {
    public struct Section {
        public let indices: [Int]
        public let frame: CGRect
    }
    public static func make(frames: [CGRect], threshold: Int = 40, capacity: Int = 18) -> [Section] {
        guard frames.count > threshold else { return [] }
        func split(_ indices: [Int]) -> [Section] {
            let frame = indices.reduce(CGRect.null) { $0.union(frames[$1]) }
            guard indices.count > max(1, capacity) else { return [Section(indices: indices, frame: frame)] }
            let xs = indices.map { frames[$0].midX }, ys = indices.map { frames[$0].midY }
            let horizontal = (xs.max()! - xs.min()!) > (ys.max()! - ys.min()!)
            let sorted = indices.sorted {
                let a = horizontal ? frames[$0].midX : frames[$0].midY
                let b = horizontal ? frames[$1].midX : frames[$1].midY
                return a == b ? $0 < $1 : a < b
            }
            let middle = sorted.count / 2
            return split(Array(sorted[..<middle])) + split(Array(sorted[middle...]))
        }
        return split(Array(frames.indices))
    }
}
