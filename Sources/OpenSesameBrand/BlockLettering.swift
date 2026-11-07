import AppKit
import OpenSesameCore

/// The wordmark's own half-block cells, reused at any size. Its seven existing
/// glyphs are sliced directly from the source artwork; the remaining capitals
/// extend that same four-row grid. No installed or imported font is involved.
public enum BlockLettering {
    public struct Cell {
        public let frame: CGRect
        public let character: Int
        public let opacity: CGFloat
    }
    public static let glyphs: [Character: [String]] = {
        let top = Array(BrandArtwork.top), bottom = Array(BrandArtwork.bottom)
        let originals: [(Character, Range<Int>)] = [
            ("O", 0..<3), ("P", 4..<7), ("E", 8..<11), ("N", 12..<16),
            ("S", 18..<20), ("A", 28..<31), ("M", 32..<37)
        ]
        var result: [Character: [String]] = [
            "B": ["█▀▄", "█▄█"], "C": ["█▀▀", "█▄▄"], "D": ["█▀▄", "█▄▀"],
            "F": ["█▀▀", "█▀░"], "G": ["█▀▀", "█▄█"], "H": ["█░█", "█▀█"],
            "I": ["▀█▀", "▄█▄"], "J": ["░░█", "█▄█"], "K": ["█▄▀", "█░█"],
            "L": ["█░░", "█▄▄"], "Q": ["█▀█░", "█▄█▄"], "R": ["█▀█", "█▀▄"],
            "T": ["▀█▀", "░█░"], "U": ["█░█", "█▄█"], "V": ["█░█", "▀▄▀"],
            "W": ["█░░░█", "█▄▀▄█"], "X": ["▀▄▀", "█░█"], "Y": ["█▄█", "░█░"],
            "Z": ["▀▀█", "█▄▄"],
            "1": ["▄█░", "▄█▄"], "2": ["▀▀█", "█▄▄"], "3": ["▀██", "▄▄█"],
            "4": ["█░█", "▀▀█"], "5": ["█▀▀", "▄▄█"]
        ]
        for (letter, range) in originals { result[letter] = [String(top[range]), String(bottom[range])] }
        return result
    }()

    public static func columns(for text: String) -> Int {
        let letters = Array(text.uppercased())
        return letters.reduce(0) { $0 + (glyphs[$1]?.first?.count ?? 0) } + max(0, letters.count - 1)
    }
    public static func aspectRatio(for text: String) -> CGFloat {
        // The logo uses 12-point columns and four 16-point half-block rows.
        CGFloat(columns(for: text)) * 12 / 64
    }
    public static func cells(for text: String, in rect: CGRect) -> [Cell] {
        let columns = columns(for: text)
        guard columns > 0 else { return [] }
        let cellWidth = rect.width / CGFloat(columns), halfHeight = rect.height / 4
        var column = 0
        var result: [Cell] = []
        for (index, letter) in text.uppercased().enumerated() {
            guard let rows = glyphs[letter] else { continue }
            for (row, blocks) in rows.enumerated() {
                for (offset, block) in blocks.enumerated() {
                    let spans: [(Int, Int)] = block == "█" || block == "░" ? [(0, 2)] : block == "▀" ? [(0, 1)] : block == "▄" ? [(1, 1)] : []
                    for (half, height) in spans {
                        let frame = CGRect(x: rect.minX + CGFloat(column + offset) * cellWidth,
                            y: rect.maxY - CGFloat(row * 2 + half + height) * halfHeight,
                            width: cellWidth, height: CGFloat(height) * halfHeight)
                        result.append(Cell(frame: frame, character: index, opacity: block == "░" ? 0.25 : 1))
                    }
                }
            }
            column += rows[0].count + 1
        }
        return result
    }
    public static func draw(_ text: String, in rect: CGRect, accent: NSColor, typed: NSColor, prefixLength: Int, background: NSColor) {
        let cells = cells(for: text, in: rect)
        // One halo under the complete glyph keeps adjacent block seams clean.
        let silhouette = NSBezierPath()
        for cell in cells where cell.opacity == 1 { silhouette.appendRect(cell.frame) }
        background.setStroke(); silhouette.lineWidth = 4; silhouette.lineJoinStyle = .miter; silhouette.stroke()
        for cell in cells {
            (cell.character < prefixLength ? typed : accent).withAlphaComponent(cell.opacity).setFill()
            cell.frame.fill()
        }
    }
}
