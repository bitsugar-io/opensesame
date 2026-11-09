import Foundation

public enum TargetExclusion {
    public static func excludes(role: String, subrole: String, title: String, description: String, kind: TargetKind, bundleID: String = "", action: String = "") -> Bool {
        // A toolbar is a container, even when its provider advertises ShowMenu.
        // Discovery still traverses its children before applying this policy.
        if role == "AXToolbar" { return true }
        // Native containers can advertise a generic context menu over their
        // complete subtree. That is not a separate control. Real AXPress groups
        // remain eligible, and descendants are still visited normally.
        if action == "AXShowMenu", role == "AXGroup" || (role == "AXTabGroup" && kind != .tab) { return true }
        if kind == .close || ["AXCloseButton", "AXMinimizeButton", "AXZoomButton", "AXFullScreenButton", "AXGrowArea"].contains(subrole) || ["AXCloseButton", "AXMinimizeButton", "AXZoomButton", "AXFullScreenButton", "AXGrowArea"].contains(role) { return true }
        if bundleID == "com.mitchellh.ghostty", role == "AXButton", kind == .control,
           [title, description].contains(where: {
               let label = $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
               return label == "update available" || label.hasPrefix("update available:")
           }) { return true }
        if kind == .tab { return false }
        guard ["AXButton", "AXMenuItem", "AXRadioButton"].contains(role) else { return false }
        let labels = [title, description].map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        return labels.contains { label in
            ["close", "quit", "force quit"].contains { verb in
                label == verb || label.hasPrefix(verb + " ") || label.hasPrefix(verb + "…") || label.hasPrefix(verb + "...")
            } || ["minimize", "minimize window", "minimize button", "maximize", "maximize window", "maximize button", "zoom", "zoom window", "zoom button", "full screen", "enter full screen", "exit full screen", "toggle full screen"].contains(label)
        }
    }
}
