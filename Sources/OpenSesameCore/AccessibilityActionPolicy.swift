/// Shared semantic action selection. Providers may supply metadata, but never
/// choose layout or replace a primary action with a context/edit menu.
public enum AccessibilityActionPolicy {
    public static let tabGroupClick = "OpenSesamePrimaryTabGroupClick"
    public static let togglePrefix = "OpenSesameToggle:"
    public static let disclosureAttributes = ["AXExpanded", "AXDisclosing"]
    public static func mayDisclose(role: String) -> Bool {
        ["AXDisclosureTriangle", "AXRow", "AXGroup", "AXTabGroup", "AXButton", "AXCell", "AXOutline"].contains(role)
    }

    public static func primary(role: String, kind: TargetKind, advertised: [String], writableDisclosure: String? = nil) -> String? {
        if let key = writableDisclosure, disclosureAttributes.contains(key) { return togglePrefix + key }
        if let primary = ["AXPress", "AXOpen"].first(where: advertised.contains) { return primary }
        if kind == .tab {
            return role == "AXTabGroup" && advertised.contains("AXShowMenu") ? tabGroupClick : nil
        }
        // A desktop object needs an open/disclosure action. A context menu by
        // itself is not an instruction to open a file or expand a stack.
        if kind == .desktop { return nil }
        return advertised.contains("AXShowMenu") ? "AXShowMenu" : nil
    }

    public static func desktopRoleIsEligible(_ role: String) -> Bool {
        !["", "AXApplication", "AXWindow", "AXScrollArea", "AXToolbar", "AXMenuBar", "AXMenu", "AXMenuItem", "AXStaticText"].contains(role)
    }
}
