import CoreGraphics

/// Shared geometry for every application: no app names or widget labels.
public enum WidgetLayout {
    public static let gap: CGFloat = 6
    public static let maximumDetachedGap: CGFloat = 48
    public static func isAssociated(_ badge: CGRect, with control: CGRect) -> Bool {
        let dx = max(0, max(control.minX - badge.maxX, badge.minX - control.maxX))
        let dy = max(0, max(control.minY - badge.maxY, badge.minY - control.maxY))
        return hypot(dx, dy) <= maximumDetachedGap
    }
    public static func contentSurface(reported: CGRect, controls: [CGRect], text: [CGRect]) -> CGRect {
        let controls = controls.filter { reported.intersects($0) }
        guard let first = controls.first else { return reported }
        let content = controls.dropFirst().reduce(first) { $0.union($1) }
        // Some popup providers include a full-display transparent host. Use its
        // visible content bounds for placement, while discovery keeps its scope.
        guard reported.width > content.width + 80 || reported.height > content.height + 100 else { return reported }
        let nearbyText = text.filter { $0.width < 400 && $0.height < 180 && content.insetBy(dx: -100, dy: -60).intersects($0) }
        return nearbyText.reduce(content) { $0.union($1) }.insetBy(dx: -12, dy: -12).intersection(reported)
    }
    public static func nearby(control: CGRect, badge: CGSize, bounds: CGRect, occupied: [CGRect], controls: [CGRect], text: [CGRect]) -> CGRect? {
        // AppKit coordinates: larger y is above. Start just left of the
        // target's upper corner, then try aligned gutters at screen edges.
        let left = control.minX - badge.width / 2
        let center = control.midX - badge.width / 2
        let below = CGRect(x: center, y: control.minY - gap - badge.height, width: badge.width, height: badge.height)
        let above = CGRect(x: center, y: control.maxY + gap, width: badge.width, height: badge.height)
        let upperLeft = CGRect(x: left, y: control.maxY + gap, width: badge.width, height: badge.height)
        let leftSide = CGRect(x: control.minX - gap - badge.width, y: control.midY - badge.height / 2, width: badge.width, height: badge.height)
        // A vertical toolbar keeps one shared side, including its end buttons.
        // Two lanes accommodate badges taller than the control pitch.
        let verticalGroup = control.width <= 72 && control.height <= 40 && controls.contains { other in
            other != control && other.width <= 72 && other.height <= 40 &&
            abs(other.midX - control.midX) <= 4 &&
            abs(other.midY - control.midY) <= (other.height + control.height) / 2 + 12 &&
            !other.intersects(control)
        }
        let candidates = verticalGroup
            ? [leftSide, leftSide.offsetBy(dx: -badge.width - gap, dy: 0), upperLeft, above, below]
            : [upperLeft, above, below, leftSide]
        let obstacles = controls.filter { $0 == control || !$0.contains(control) } + text
        return candidates.first { frame in
            bounds.insetBy(dx: 4, dy: 4).contains(frame) &&
            !occupied.contains { $0.insetBy(dx: -5, dy: -5).intersects(frame) } &&
            !obstacles.contains { $0.insetBy(dx: -2, dy: -2).intersects(frame) }
        }
    }
    /// A last-resort annotation beneath the popup. Include its caption in the
    /// collision reservation; no control or text may be hidden by this badge.
    public static func exterior(control: CGRect, surface: CGRect, badge: CGSize, bounds: CGRect, occupied: [CGRect], obstacles: [CGRect], captionHeight: CGFloat = 14) -> CGRect? {
        let step = badge.width + 12
        // Keep local columns first. When readable captions fill those, extend
        // the horizontal annotation strip rather than silently losing actions.
        for lane in 0..<80 {
            let wide = lane >= 40
            let left = wide ? bounds.minX + 4 : max(bounds.minX + 4, surface.minX)
            let right = wide ? bounds.maxX - badge.width - 4 : min(bounds.maxX - badge.width - 4, max(left, surface.maxX - badge.width))
            let columns = max(1, Int((right - left) / step) + 1)
            let preferred = min(max(control.midX - badge.width / 2, left), right)
            let sideLane = lane % 40
            let row = sideLane % 20
            let y = sideLane < 20
                ? surface.minY - 8 - badge.height - CGFloat(row) * (badge.height + captionHeight + 8)
                : surface.maxY + 8 + captionHeight + CGFloat(row) * (badge.height + captionHeight + 8)
            let offsets = (0..<columns).sorted { abs(left + CGFloat($0) * step - preferred) < abs(left + CGFloat($1) * step - preferred) }
            let xs = [preferred] + offsets.map { left + CGFloat($0) * step }
            for x in xs {
                let frame = CGRect(x: x, y: y, width: badge.width, height: badge.height)
                let reservation = frame.union(frame.offsetBy(dx: 0, dy: -captionHeight))
                if isAssociated(frame, with: control), bounds.insetBy(dx: 4, dy: 4).contains(reservation),
                   !occupied.contains(where: { $0.insetBy(dx: -4, dy: -4).intersects(reservation) }),
                   !obstacles.contains(where: { $0.insetBy(dx: -2, dy: -2).intersects(reservation) }) {
                    return frame
                }
            }
        }
        return nil
    }

}
