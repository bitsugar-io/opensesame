import CoreGraphics

public enum BadgeLayout {
    /// Object labels sit just inside a visible corner, with the same four-point
    /// inset as inline tab labels. Never place over an occluding window.
    public static func insideObject(control: CGRect, visible: [CGRect], badge: CGSize, bounds: CGRect, occupied: [CGRect]) -> CGRect? {
        let spaces = VisibleRegion.exposed(frame: control, screens: visible.map { $0.intersection(bounds.insetBy(dx: 4, dy: 4)) }, occluders: [])
            .sorted { $0.maxY == $1.maxY ? $0.minX < $1.minX : $0.maxY > $1.maxY }
        for space in spaces {
            let room = space.insetBy(dx: 4, dy: 4)
            guard room.width >= badge.width, room.height >= badge.height else { continue }
            for corner in [CGPoint(x: room.maxX - badge.width, y: room.maxY - badge.height), CGPoint(x: room.minX, y: room.maxY - badge.height),
                           CGPoint(x: room.minX, y: room.minY), CGPoint(x: room.maxX - badge.width, y: room.minY)] {
                let frame = CGRect(origin: corner, size: badge)
                if !occupied.contains(where: { $0.insetBy(dx: -3, dy: -3).intersects(frame) }) { return frame }
            }
        }
        return nil
    }
    /// Tab choices belong inside the selected window's tab strip. A compact
    /// vertical inset removes badge padding before reducing any glyph size.
    public static func insideTab(control: CGRect, badge: CGSize, textHeight: CGFloat, bounds: CGRect, occupied: [CGRect]) -> CGRect? {
        let height = min(badge.height, control.height - 2)
        guard height >= textHeight, badge.width <= control.width - 8 else { return nil }
        // Prefer the trailing space, then try either edge of measured titles,
        // icons, and other hints. Keep the complete code within the tab.
        let edges = occupied.flatMap { [$0.minX - badge.width - 4, $0.maxX + 4] }
        let candidates = ([control.maxX - badge.width - 4, control.minX + 4, control.midX - badge.width / 2] + edges).map {
            CGRect(x: $0, y: control.midY - height / 2, width: badge.width, height: height)
        }
        return candidates.first { frame in
            control.contains(frame) && bounds.insetBy(dx: 4, dy: 4).contains(frame) &&
            !occupied.contains { $0.insetBy(dx: -3, dy: -3).intersects(frame) }
        }
    }
    // Keep each connector on one axis. Vary length, never the row/column.
    public static func candidates(control: CGRect, badge: CGSize, menuBar: Bool, index: Int, bounds: CGRect? = nil) -> [CGRect] {
        let gap: CGFloat = 6
        let stagger = CGFloat(index % 2) * (menuBar ? badge.height + 6 : badge.width + 6)
        let preferLeft = control.midX > (bounds?.midX ?? .greatestFiniteMagnitude)
        // Choose the side once from the whole surface, allowing room for both
        // lanes. Collision handling can extend a leader, never switch its side.
        let requiredRoom = gap + badge.width * 2 + 6
        let leftFits = bounds.map { control.minX - requiredRoom >= $0.minX + 4 } ?? true
        let rightFits = bounds.map { control.maxX + requiredRoom <= $0.maxX - 4 } ?? true
        let useLeft = preferLeft ? (leftFits || !rightFits) : (!rightFits && leftFits)
        return (0..<8).flatMap { step -> [CGRect] in
            let distance = gap + stagger + CGFloat(step) * (menuBar ? badge.height + 6 : badge.width + 6)
            if menuBar {
                return [CGRect(x: control.midX - badge.width / 2, y: control.minY - distance - badge.height, width: badge.width, height: badge.height)]
            }
            let y = control.midY - badge.height / 2
            if bounds != nil && !leftFits && !rightFits {
                // Full-width windows have no exterior margin. Keep both lanes
                // just inside one edge rather than dropping every hint.
                let x = preferLeft ? control.minX + distance : control.maxX - distance - badge.width
                return [CGRect(x: x, y: y, width: badge.width, height: badge.height)]
            }
            let right = CGRect(x: control.maxX + distance, y: y, width: badge.width, height: badge.height)
            let left = CGRect(x: control.minX - distance - badge.width, y: y, width: badge.width, height: badge.height)
            if bounds == nil { return preferLeft ? [left, right] : [right, left] }
            return [useLeft ? left : right]
        }
    }

    // Prefer clear space, then permit covering UI rather than stacking two labels.
    // A fixed separation keeps codes distinct even in a dense menu bar.
    public static func place(candidates: [CGRect], bounds: CGRect, occupied: [CGRect], controls: [CGRect], spacing: CGFloat = 5) -> CGRect? {
        let fitting = candidates.filter { bounds.insetBy(dx: 4, dy: 4).contains($0) }
        let separated = fitting.filter { candidate in
            !occupied.contains { $0.insetBy(dx: -spacing, dy: -spacing).intersects(candidate) }
        }
        let nearby = Array(fitting.prefix(4))
        return separated.first(where: { candidate in
            nearby.contains(candidate) && !controls.contains { $0.intersects(candidate) }
        }) ?? separated.first
    }
}
