import CoreGraphics

/// Subtract frontmost surfaces without joining disjoint exposed strips.
/// Coordinates may use either origin; all inputs must use the same space.
public enum VisibleRegion {
    public static func subtract(_ obstacle: CGRect, from region: CGRect) -> [CGRect] {
        let overlap = region.intersection(obstacle)
        guard !overlap.isNull, overlap.width > 0, overlap.height > 0 else { return [region] }
        return [
            CGRect(x: region.minX, y: region.minY, width: region.width, height: overlap.minY - region.minY),
            CGRect(x: region.minX, y: overlap.maxY, width: region.width, height: region.maxY - overlap.maxY),
            CGRect(x: region.minX, y: overlap.minY, width: overlap.minX - region.minX, height: overlap.height),
            CGRect(x: overlap.maxX, y: overlap.minY, width: region.maxX - overlap.maxX, height: overlap.height)
        ].filter { $0.width > 0 && $0.height > 0 }
    }

    public static func exposed(frame: CGRect, screens: [CGRect], occluders: [CGRect]) -> [CGRect] {
        var regions = screens.map { frame.intersection($0) }.filter { !$0.isNull && $0.width > 0 && $0.height > 0 }
        for obstacle in occluders { regions = regions.flatMap { subtract(obstacle, from: $0) } }
        return regions
    }
}
