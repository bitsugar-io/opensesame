import CoreGraphics

public enum TargetGeometry {
    public static func isVisible(frame: CGRect, viewport: CGRect) -> Bool {
        frame.width > 0 && frame.height > 0 && viewport.contains(CGPoint(x: frame.midX, y: frame.midY))
    }

    // AX providers animate and round frames between discovery and activation.
    // Accept local settling, but never a materially relocated/resized target.
    public static func isStable(previous: CGRect, current: CGRect) -> Bool {
        guard previous.width > 0, previous.height > 0, current.width > 0, current.height > 0 else { return false }
        let drift = max(abs(previous.minX - current.minX), abs(previous.maxX - current.maxX),
                        abs(previous.minY - current.minY), abs(previous.maxY - current.maxY))
        let overlap = previous.intersection(current)
        guard !overlap.isNull else { return false }
        return drift <= 12 && overlap.width * overlap.height / max(previous.width * previous.height, current.width * current.height) >= 0.8
    }
}
