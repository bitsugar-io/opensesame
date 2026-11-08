import ApplicationServices

/// Provider-independent child discovery. A menu's advertised visible rows are
/// authoritative; ordinary containers may expose a separate navigation tree.
enum AccessibilityTraversal {
    static func window(of element: AXUIElement, read: (AXUIElement, String) -> CFTypeRef? = attribute) -> AXUIElement? {
        var current = element
        var seen: [AXUIElement] = []
        for _ in 0..<16 {
            guard !seen.contains(where: { CFEqual($0, current) }) else { return nil }
            seen.append(current)
            if read(current, kAXRoleAttribute) as? String == kAXWindowRole { return current }
            if let window = read(current, kAXWindowAttribute), CFGetTypeID(window) == AXUIElementGetTypeID() { return (window as! AXUIElement) }
            guard let parent = read(current, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() else { return nil }
            current = parent as! AXUIElement
        }
        return nil
    }
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
