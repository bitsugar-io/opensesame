import CoreGraphics

public enum ActionDuplicate {
    // A named cell and button may describe the same action through two AX nodes.
    // Require real ancestry as well as matching semantics and near-identical rows.
    public static func matches(owner: Int32, otherOwner: Int32, name: String, otherName: String,
                               frame: CGRect, otherFrame: CGRect, related: Bool) -> Bool {
        guard related, owner == otherOwner, !name.isEmpty, name == otherName else { return false }
        return MenuRow(owner: owner, frame: frame).sharesVisibleRow(with: MenuRow(owner: otherOwner, frame: otherFrame))
    }
}
