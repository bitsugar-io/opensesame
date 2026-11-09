import CoreGraphics

/// One navigation level contains at most three regions, separated by empty
/// corridors between whole controls. Dense regions can be subdivided on entry.
public enum HintSections {
    public struct Section {
        public let indices: [Int]
        public let frame: CGRect
    }
    public static func make(frames: [CGRect], threshold: Int = 40, capacity: Int = 18, bounds: CGRect? = nil) -> [Section] {
        guard frames.count > threshold else { return [] }
        func readingOrder(_ a: Int, _ b: Int) -> Bool {
            let lhs = frames[a], rhs = frames[b]
            if lhs.minY != rhs.minY { return lhs.minY < rhs.minY }
            if lhs.minX != rhs.minX { return lhs.minX < rhs.minX }
            if lhs.height != rhs.height { return lhs.height < rhs.height }
            if lhs.width != rhs.width { return lhs.width < rhs.width }
            return a < b
        }
        func split(_ indices: [Int]) -> (left: [Int], right: [Int], horizontal: Bool, boundary: CGFloat)? {
            guard indices.count > max(1, capacity) else { return nil }
            var best: (ordered: [Int], cut: Int, score: CGFloat, horizontal: Bool, boundary: CGFloat)?
            for horizontal in [true, false] {
                func start(_ index: Int) -> CGFloat { horizontal ? frames[index].minX : frames[index].minY }
                func end(_ index: Int) -> CGFloat { horizontal ? frames[index].maxX : frames[index].maxY }
                let ordered = indices.sorted { start($0) == start($1) ? readingOrder($0, $1) : start($0) < start($1) }
                var extent = end(ordered[0])
                for cut in 1..<ordered.count {
                    let gap = start(ordered[cut]) - extent
                    let boundary = (start(ordered[cut]) + extent) / 2
                    extent = max(extent, end(ordered[cut]))
                    // Leave room for the outline, and do not carve individual
                    // outliers into tiny sections just to meet a count quota.
                    guard gap >= 8, cut >= 2, ordered.count - cut >= 2 else { continue }
                    let balance = CGFloat(min(cut, ordered.count - cut)) / CGFloat(max(cut, ordered.count - cut))
                    let score = gap * balance.squareRoot()
                    if best == nil || score > best!.score { best = (ordered, cut, score, horizontal, boundary) }
                }
            }
            guard let best else { return nil }
            return (Array(best.ordered[..<best.cut]), Array(best.ordered[best.cut...]), best.horizontal, best.boundary)
        }
        let whole = frames.reduce(CGRect.null) { $0.union($1) }
        // Logical pane bounds belong to navigation. Control rectangles decide
        // membership and clean split locations; they do not trim the outer edge.
        // If a provider reports controls beyond its window, retain its measured
        // geometry rather than inventing a pane that excludes a known target.
        let scope = bounds.flatMap { $0.contains(whole) ? $0 : nil }
        var groups = [(indices: Array(frames.indices), pane: scope)]
        while groups.count < 3 {
            // Spend the next split on the most crowded region, not on every
            // branch of the tree. The remaining detail appears after selection.
            let candidates = groups.indices.sorted {
                groups[$0].indices.count == groups[$1].indices.count ? $0 < $1 : groups[$0].indices.count > groups[$1].indices.count
            }
            guard let choice = candidates.lazy.compactMap({ index in split(groups[index].indices).map { (index, $0) } }).first else { break }
            let split = choice.1
            var left = groups[choice.0].pane, right = left
            if let pane = left {
                // An eight-point gutter keeps neighboring three-point borders
                // distinct. The split corridor is at least this wide.
                if split.horizontal {
                    left = CGRect(x: pane.minX, y: pane.minY, width: split.boundary - 4 - pane.minX, height: pane.height)
                    right = CGRect(x: split.boundary + 4, y: pane.minY, width: pane.maxX - split.boundary - 4, height: pane.height)
                } else {
                    left = CGRect(x: pane.minX, y: pane.minY, width: pane.width, height: split.boundary - 4 - pane.minY)
                    right = CGRect(x: pane.minX, y: split.boundary + 4, width: pane.width, height: pane.maxY - split.boundary - 4)
                }
            }
            groups.replaceSubrange(choice.0...choice.0, with: [(split.left, left), (split.right, right)])
        }
        var sections: [Section] = []
        for group in groups {
            let indices = group.indices
            let frame = group.pane ?? indices.reduce(CGRect.null) { $0.union(frames[$1]) }
            sections.append(Section(indices: indices.sorted(by: readingOrder), frame: frame))
        }
        sections.sort {
            $0.frame.minY == $1.frame.minY ? $0.frame.minX < $1.frame.minX : $0.frame.minY < $1.frame.minY
        }
        // A single box adds a keystroke without narrowing the choices.
        return sections.count > 1 ? sections : []
    }
}
