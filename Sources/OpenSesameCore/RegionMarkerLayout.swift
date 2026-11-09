import CoreGraphics

/// Large region codes prefer the center. Occluded windows use the largest
/// exposed space that can hold the complete code; other labels stay obstacles.
public enum RegionMarkerLayout {
    /// Give a narrow section a pane-sized outline when its surrounding gutter
    /// is clear. Never expand across another section or the display boundary.
    public static func sectionFrame(_ frame: CGRect, bounds: CGRect, neighbors: [CGRect]) -> CGRect {
        let width = max(96, frame.width), height = max(96, frame.height)
        let expanded = CGRect(x: frame.midX - width / 2, y: frame.midY - height / 2, width: width, height: height)
        let clipped = expanded.intersection(bounds.insetBy(dx: 4, dy: 4))
        let expandedNeighbors = neighbors.map {
            CGRect(x: $0.midX - max(96, $0.width) / 2, y: $0.midY - max(96, $0.height) / 2,
                   width: max(96, $0.width), height: max(96, $0.height))
        }
        guard clipped.contains(frame), !expandedNeighbors.contains(where: { $0.insetBy(dx: -8, dy: -8).intersects(clipped) }) else { return frame }
        return clipped
    }
    public static func place(region: CGRect, visible: [CGRect], aspectRatio: CGFloat, fontSize: CGFloat,
                             bounds: CGRect, occupied: [CGRect]) -> CGRect? {
        guard aspectRatio > 0 else { return nil }
        let spaces = VisibleRegion.exposed(frame: region, screens: visible.map { $0.intersection(bounds.insetBy(dx: 4, dy: 4)) },
                                          occluders: occupied.map { $0.insetBy(dx: -8, dy: -8) })
        let preferredHeight = max(48, min(96, fontSize * 4))
        let minimumHeight = max(16, fontSize)
        var choices: [(frame: CGRect, area: CGFloat, distance: CGFloat)] = []
        for space in spaces {
            let room = space.insetBy(dx: 8, dy: 8)
            let height = floor(min(preferredHeight, room.height, room.width / aspectRatio) / 4) * 4
            guard height >= minimumHeight else { continue }
            let width = height * aspectRatio
            let center = CGPoint(x: region.midX, y: region.midY)
            let preferred = room.contains(center) ? center : CGPoint(x: room.midX, y: room.midY)
            let x = min(max(preferred.x - width / 2, room.minX), room.maxX - width)
            let y = min(max(preferred.y - height / 2, room.minY), room.maxY - height)
            let frame = CGRect(x: x, y: y, width: width, height: height)
            choices.append((frame, room.width * room.height, abs(frame.midX - center.x) + abs(frame.midY - center.y)))
        }
        return choices.sorted {
            if $0.frame.height != $1.frame.height { return $0.frame.height > $1.frame.height }
            if $0.distance == 0 || $1.distance == 0 { return $0.distance < $1.distance }
            if $0.area != $1.area { return $0.area > $1.area }
            if $0.distance != $1.distance { return $0.distance < $1.distance }
            return $0.frame.minY == $1.frame.minY ? $0.frame.minX < $1.frame.minX : $0.frame.minY < $1.frame.minY
        }.first?.frame
    }
}
