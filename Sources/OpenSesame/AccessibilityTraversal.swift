import ApplicationServices

/// Provider-independent child discovery. A menu's advertised visible rows are
/// authoritative; ordinary containers may expose a separate navigation tree.
enum AccessibilityTraversal {
    static func children(of element: AXUIElement, role: String,
                         read: (AXUIElement, String) -> CFTypeRef? = attribute) -> [AXUIElement] {
        if role == kAXMenuRole, let visible = read(element, kAXVisibleChildrenAttribute) as? [AXUIElement] { return visible }
        let children = read(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
        guard children.isEmpty,
              ["AXApplication", "AXWindow", "AXGroup", "AXWebArea", "AXScrollArea", "AXSplitGroup", "AXTabGroup", "AXOutline", "AXList", "AXTable", "AXRow"].contains(role) else { return children }
        for key in ["AXChildrenInNavigationOrder", kAXContentsAttribute] {
            if let alternative = read(element, key) as? [AXUIElement], !alternative.isEmpty { return alternative }
        }
        return []
    }
}
