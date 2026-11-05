import CoreGraphics

public enum BadgeLayout {
    public static func windowTitle(control: CGRect, badge: CGSize) -> [CGRect] {
        [0, -1, 1, -2, 2, -3, 3].map { offset in
            CGRect(x: control.midX - badge.width / 2 + CGFloat(offset) * (badge.width + 6),
                   y: control.maxY - badge.height - 4, width: badge.width, height: badge.height)
        }.filter { control.insetBy(dx: 4, dy: 0).contains($0) }
    }

    public static func inlineTabCandidates(control: CGRect, badge: CGSize) -> [CGRect] {
        guard let preferred = inlineTab(control: control, badge: badge) else { return [] }
        return (0..<4).map { preferred.offsetBy(dx: CGFloat($0) * (badge.width + 6), dy: 0) }
            .filter { control.insetBy(dx: 4, dy: 0).contains($0) }
    }
    public static func inlineTab(control: CGRect, badge: CGSize) -> CGRect? {
        guard control.width >= badge.width + 16, control.height >= 14 else { return nil }
        let height = min(badge.height, control.height)
        return CGRect(x: control.minX + 8, y: control.midY - height / 2, width: badge.width, height: height)
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
