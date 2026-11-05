import Foundation
import CoreGraphics

public struct Surface: Equatable {
    public let id: UInt32
    public let pid: Int32
    public let frame: CGRect
    public let layer: Int
    public init(id: UInt32, pid: Int32, frame: CGRect, layer: Int = 0) {
        self.id = id; self.pid = pid; self.frame = frame; self.layer = layer
    }
    public static func == (lhs: Surface, rhs: Surface) -> Bool {
        lhs.id == rhs.id && lhs.pid == rhs.pid && lhs.layer == rhs.layer &&
        lhs.frame.minX == rhs.frame.minX && lhs.frame.minY == rhs.frame.minY &&
        lhs.frame.width == rhs.frame.width && lhs.frame.height == rhs.frame.height
    }
    public static func menus(in surfaces: [Surface], owners: Set<Int32>, menuLayer: Int) -> [Surface] {
        surfaces.filter { owners.contains($0.pid) && $0.layer == menuLayer }
    }
    // Input order is front to back. Never fall back to an unrelated old window.
    public static func opened(before: [Surface], after: [Surface], owners: Set<Int32>, activatedOwner: Int32? = nil) -> Surface? {
        // A newly opened/resized popup takes priority over an existing window
        // that happens to own keyboard focus (including focus-follows-mouse).
        if let changed = after.first(where: { candidate in
            owners.contains(candidate.pid) && candidate.frame.width > 2 && candidate.frame.height > 2 &&
            !before.contains(candidate)
        }) { return changed }
        // An app can bring forward an existing window without creating it.
        if let activatedOwner, owners.contains(activatedOwner),
           let existing = after.first(where: { $0.pid == activatedOwner && $0.frame.width > 2 && $0.frame.height > 2 }) {
            return existing
        }
        return nil
    }
}
