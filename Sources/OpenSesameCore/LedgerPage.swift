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

    public init(items: Int, requestedPage: Int, bounds: CGRect, surface: CGRect, fontSize: CGFloat, codeWidth: CGFloat) {
        rowHeight = ceil(fontSize) + 18
        rowsPerColumn = max(1, Int((bounds.height - 92) / rowHeight))
        let desiredWidth = max(264, codeWidth + 160)
        let leftRoom = max(0, surface.minX - bounds.minX - 24)
        let rightRoom = max(0, bounds.maxX - surface.maxX - 24)
        let useLeft = leftRoom >= desiredWidth || leftRoom >= rightRoom
        let sideRoom = useLeft ? leftRoom : rightRoom
        columnWidth = min(desiredWidth, max(1, bounds.width - 24))
        let maxColumns = max(1, Int(sideRoom / columnWidth))
        let columns = min(maxColumns, max(1, Int(ceil(Double(items) / Double(rowsPerColumn)))))
        let capacity = rowsPerColumn * columns
        count = max(1, Int(ceil(Double(items) / Double(capacity))))
        number = ((requestedPage % count) + count) % count
        let start = min(items, number * capacity)
        range = start..<min(items, start + capacity)
        let width = CGFloat(columns) * columnWidth
        // Keep the panel the same size on the last page and during page changes.
        let height = min(bounds.height - 24, CGFloat(min(rowsPerColumn, max(1, items))) * rowHeight + 64)
        let x = useLeft ? surface.minX - width - 12 : surface.maxX + 12
        panel = CGRect(x: min(max(bounds.minX + 12, x), max(bounds.minX + 12, bounds.maxX - width - 12)),
                       y: min(max(bounds.minY + 12, surface.maxY - height), bounds.maxY - height - 12), width: width, height: height)
    }
}
