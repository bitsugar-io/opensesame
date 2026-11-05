import CoreGraphics

public enum WindowMatching {
    // Match mutual unique nearest frames. Identical saved geometry across Spaces
    // is ambiguous; never map two AX windows to the same visible CG window.
    public static func visibleIndices(windows: [CGRect], surfaces: [CGRect]) -> [Int] {
        guard surfaces.count > 1 else { return [] }
        func score(_ a: CGRect, _ b: CGRect) -> CGFloat? {
            let shared = a.intersection(b)
            guard !shared.isNull, a.width > 0, a.height > 0, b.width > 0, b.height > 0,
                  shared.width * shared.height / max(a.width * a.height, b.width * b.height) > 0.8 else { return nil }
            return abs(a.minX - b.minX) + abs(a.minY - b.minY) + abs(a.maxX - b.maxX) + abs(a.maxY - b.maxY)
        }
        func nearest(_ scores: [(Int, CGFloat)]) -> Int? {
            let sorted = scores.sorted { $0.1 < $1.1 }
            guard let first = sorted.first else { return nil }
            guard sorted.count == 1 || sorted[1].1 - first.1 > 0.5 else { return nil }
            return first.0
        }
        return windows.indices.filter { index in
            guard let match = nearest(surfaces.indices.compactMap { j in score(windows[index], surfaces[j]).map { (j, $0) } }) else { return false }
            return nearest(windows.indices.compactMap { j in score(windows[j], surfaces[match]).map { (j, $0) } }) == index
        }
    }
}
