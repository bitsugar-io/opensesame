import CoreGraphics

/// Local candidates for a section caption; the shared placement pass checks
/// text, controls, and other hint reservations before accepting any candidate.
public enum SectionLabelLayout {
    public static func candidates(section: CGRect, badge: CGSize, bounds: CGRect) -> [CGRect] {
        guard badge.width <= bounds.width - 8, badge.height <= bounds.height - 8 else { return [] }
        var result: [CGRect] = []
        let xs = [section.minX, section.midX - badge.width / 2, section.maxX - badge.width]
        for y in [section.maxY + 6, section.minY - badge.height - 6] {
            for x in xs { result.append(CGRect(x: x, y: y, width: badge.width, height: badge.height)) }
        }
        // Search empty interior gutters rather than fixing every label to the
        // same top edge. Ordering is stable while a prefix is being typed.
        var y = section.maxY - badge.height - 6
        while y >= section.minY + 6, result.count < 180 {
            for x in xs { result.append(CGRect(x: x, y: y, width: badge.width, height: badge.height)) }
            y -= badge.height + 8
        }
        return result.filter { bounds.insetBy(dx: 4, dy: 4).contains($0) }
    }
}
