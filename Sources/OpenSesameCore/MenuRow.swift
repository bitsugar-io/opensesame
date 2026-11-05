import CoreGraphics

public struct MenuRow {
    public let owner: Int32
    public let frame: CGRect
    public init(owner: Int32, frame: CGRect) { self.owner = owner; self.frame = frame }
    // Native alternate entries can have different titles and AX identities but
    // occupy the same rendered menu row. Keep one hint for that visual action.
    public func sharesVisibleRow(with other: MenuRow) -> Bool {
        guard owner == other.owner, abs(frame.midY - other.frame.midY) <= 3 else { return false }
        let shared = frame.intersection(other.frame)
        guard !shared.isNull else { return false }
        let width = min(frame.width, other.frame.width), height = min(frame.height, other.frame.height)
        return width > 0 && height > 0 && shared.width / width >= 0.8 && shared.height / height >= 0.8
    }
}
