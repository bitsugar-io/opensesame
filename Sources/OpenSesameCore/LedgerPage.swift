import Foundation

/// Paging keeps every popup action reachable without shrinking text or hiding entries.
public struct LedgerPage {
    public let panel: CGRect
    public let rowsPerColumn: Int
    public let range: Range<Int>
    public let number: Int
    public let count: Int
    public let rowHeight: CGFloat
    public let columnWidth: CGFloat

    public init(items: Int, layoutItems: Int? = nil, requestedPage: Int, bounds: CGRect, surface: CGRect, fontSize: CGFloat, codeWidth: CGFloat, avoid: [CGRect] = [], focus: CGRect? = nil) {
        rowHeight = max(ceil(fontSize) + 18, ceil(max(12, fontSize - 2) * 1.25) * 2 + 12)
        rowsPerColumn = max(1, Int((bounds.height - 92) / rowHeight))
        let desiredWidth = max(264, codeWidth + 160)
        let leftRoom = max(0, surface.minX - bounds.minX - 24)
        let rightRoom = max(0, bounds.maxX - surface.maxX - 24)
        columnWidth = min(desiredWidth, max(1, bounds.width - 24))
        // One shared rule: outside the owning window/popup on the right,
        // otherwise outside on the left. Only use an interior panel when
        // neither side can hold one full readable column.
        let useRight = rightRoom >= columnWidth
        let useLeft = !useRight && leftRoom >= columnWidth
        let exterior = useRight || useLeft
        // Keep one readable column on every side; paginate instead of widening
        // into a different layout because another app/window leaves more room.
        let layoutCount = max(items, layoutItems ?? items)
        let capacity = rowsPerColumn
        count = max(1, Int(ceil(Double(items) / Double(capacity))))
        number = ((requestedPage % count) + count) % count
        let start = min(items, number * capacity)
        range = start..<min(items, start + capacity)
        let width = columnWidth
        // Keep the panel the same size on the last page and during page changes.
        let height = min(bounds.height - 24, CGFloat(min(rowsPerColumn, max(1, layoutCount))) * rowHeight + 64)
        let relevant = focus ?? surface
        let x = useRight ? surface.maxX + 12 : (useLeft ? surface.minX - width - 12 : relevant.maxX - width - 12)
        let preferred = CGRect(x: min(max(bounds.minX + 12, x), max(bounds.minX + 12, bounds.maxX - width - 12)),
                       y: min(max(bounds.minY + 12, relevant.maxY - height), bounds.maxY - height - 12), width: width, height: height)
        if avoid.isEmpty { panel = preferred; return }
        var candidates = [preferred]
        var y = bounds.minY + 12
        while y + height <= bounds.maxY - 12 {
            // Collision avoidance may slide along the chosen side. It must
            // never pull an exterior panel back over the app's content.
            var x = exterior ? preferred.minX : bounds.minX + 12
            while x + width <= bounds.maxX - 12 {
                candidates.append(CGRect(x: x, y: y, width: width, height: height))
                if exterior { break }
                x += 24
            }
            y += 24
        }
        func collisions(_ frame: CGRect) -> Int { avoid.filter { $0.insetBy(dx: -5, dy: -5).intersects(frame) }.count }
        // Move the overflow panel before moving any successful local labels.
        panel = candidates.min { a, b in
            let ac = collisions(a), bc = collisions(b)
            if ac != bc { return ac < bc }
            let ad = abs(a.midX - preferred.midX) + abs(a.midY - preferred.midY)
            let bd = abs(b.midX - preferred.midX) + abs(b.midY - preferred.midY)
            return ad < bd
        } ?? preferred
    }
}
