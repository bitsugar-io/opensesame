import CoreGraphics

public enum CompactRowLayout {
    public struct Control {
        public let index: Int, owner: Int32
        public let frame: CGRect
        public init(index: Int, owner: Int32, frame: CGRect) { self.index = index; self.owner = owner; self.frame = frame }
    }
    public struct Placement {
        public let frame: CGRect
        public let outsideSurface: Bool
        public let reservation: CGRect
    }
    // Geometry, not app names: adjacent small controls form a row. Keep their
    // labels together in one horizontal strip, preserving left-to-right order.
    public static func arrange(controls: [Control], badge: CGSize, bounds: CGRect, surface: CGRect?, obstacles: [CGRect], captionHeight: CGFloat = 0) -> [Int: Placement] {
        let eligible = controls.filter { $0.frame.width <= 72 && $0.frame.height <= 40 && $0.frame.width >= 8 && $0.frame.height >= 8 }
        var rows: [[Control]] = []
        for control in eligible.sorted(by: { $0.frame.midY > $1.frame.midY }) {
            if let row = rows.firstIndex(where: { $0[0].owner == control.owner && abs($0[0].frame.midY - control.frame.midY) <= 4 }) { rows[row].append(control) }
            else { rows.append([control]) }
        }
        var groups: [[Control]] = []
        for row in rows {
            var group: [Control] = []
            for control in row.sorted(by: { $0.frame.minX < $1.frame.minX }) {
                if let last = group.last, control.frame.minX - last.frame.maxX > 48 || control.frame.minX < last.frame.maxX - 2 {
                    if group.count >= 2 { groups.append(group) }
                    group = []
                }
                group.append(control)
            }
            if group.count >= 2 { groups.append(group) }
        }
        var result: [Int: Placement] = [:]
        var reserved: [CGRect] = []
        for group in groups {
            let rowBottom = group.map { $0.frame.minY }.min()!
            let rowTop = group.map { $0.frame.maxY }.max()!
            let rowLeft = group.map { $0.frame.minX }.min()!
            let rowRight = group.map { $0.frame.maxX }.max()!
            let width = CGFloat(group.count) * badge.width + CGFloat(group.count - 1) * 8
            let left = min(max((rowLeft + rowRight - width) / 2, bounds.minX + 4), bounds.maxX - width - 4)
            let centers = group.map { $0.frame.midX }
            let naturallySpaced = zip(centers, centers.dropFirst()).allSatisfy { $1 - $0 >= badge.width + 8 }
            func strip(y: CGFloat) -> [CGRect] {
                group.indices.map { CGRect(x: naturallySpaced ? centers[$0] - badge.width / 2 : left + CGFloat($0) * (badge.width + 8), y: y, width: badge.width, height: badge.height) }
            }
            let ownFrames = group.map(\.frame)
            let foreign = obstacles.filter { obstacle in !ownFrames.contains(where: { obstacle != $0 && obstacle.contains($0) }) }
            func fits(_ frames: [CGRect], captions: Bool = false) -> Bool {
                frames.allSatisfy { badgeFrame in
                    let frame = captions ? badgeFrame.union(badgeFrame.offsetBy(dx: 0, dy: -captionHeight)) : badgeFrame
                    return bounds.insetBy(dx: 4, dy: 4).contains(frame) &&
                    !foreign.contains(where: { $0.insetBy(dx: -2, dy: -2).intersects(frame) }) &&
                    !reserved.contains(where: { $0.insetBy(dx: -5, dy: -5).intersects(frame) })
                }
            }
            let below = strip(y: rowBottom - 6 - badge.height)
            let above = strip(y: rowTop + 6)
            var outside = false
            var chosen = [below, above].first(where: { fits($0) })
            if chosen == nil, let surface {
                // A popup with no empty gutter gets an annotation strip below
                // its content, never opaque badges on the control's glyphs.
                for lane in 0..<max(4, groups.count) {
                    let frames = strip(y: surface.minY - 8 - badge.height - CGFloat(lane) * (badge.height + captionHeight + 8))
                    if zip(frames, group).allSatisfy({ WidgetLayout.isAssociated($0.0, with: $0.1.frame) }),
                       fits(frames, captions: true) { chosen = frames; outside = true; break }
                }
            }
            guard let frames = chosen else { continue }
            for (control, frame) in zip(group, frames) {
                let reservation = outside ? frame.union(frame.offsetBy(dx: 0, dy: -captionHeight)) : frame
                result[control.index] = Placement(frame: frame, outsideSurface: outside, reservation: reservation)
            }
            reserved += group.compactMap { result[$0.index]?.reservation }
        }
        return result
    }
}
