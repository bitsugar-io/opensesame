import AppKit
import ApplicationServices

/// Read-only, bounded inspection through the trusted running app. It never
/// activates an app, posts input, performs an AX action, or changes permissions.
enum AccessibilityInspection {
    static func json(bundleID: String) -> String {
        guard let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else { return "{}" }
        let app = AXUIElementCreateApplication(running.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.08)
        // Desktop and auxiliary windows need not be AXChildren of the app.
        let windows = attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? []
        var queue = [(app, 0)] + windows.map { ($0, 1) }, cursor = 0, seen = Set<CFHashCode>(), rows: [[String: Any]] = []
        let deadline = Date().addingTimeInterval(4)
        while cursor < queue.count, cursor < 3000, Date() < deadline {
            let (element, depth) = queue[cursor]; cursor += 1
            guard seen.insert(CFHash(element)).inserted else { continue }
            let role = attribute(element, kAXRoleAttribute) as? String ?? ""
            let children = AccessibilityTraversal.children(of: element, role: role)
            if depth < 12 { queue += children.map { ($0, depth + 1) } }
            guard !role.isEmpty else { continue }
            var actions: CFArray?, keys: CFArray?
            AXUIElementCopyActionNames(element, &actions); AXUIElementCopyAttributeNames(element, &keys)
            var row: [String: Any] = ["role": role, "depth": depth, "actions": actions as? [String] ?? [], "attributes": keys as? [String] ?? [], "children": children.count]
            if let parent = attribute(element, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() {
                row["parentRole"] = attribute(parent as! AXUIElement, kAXRoleAttribute) as? String
            }
            for key in ["AXTitle", "AXDescription", "AXIdentifier", "AXSubrole", "AXExpanded", "AXValue", "AXDisclosing", "AXHidden", "AXSelected", "AXFocused", "AXEnhancedUserInterface"] {
                if let value = attribute(element, key) as? String { row[key] = String(value.prefix(512)) }
                else if let value = attribute(element, key) as? NSNumber { row[key] = value }
                var settable = DarwinBoolean(false)
                if AXUIElementIsAttributeSettable(element, key as CFString, &settable) == .success { row[key + "Settable"] = settable.boolValue }
            }
            if let rect = elementFrame(element) { row["frame"] = ["x": rect.minX, "y": rect.minY, "width": rect.width, "height": rect.height] }
            rows.append(row)
        }
        let result: [String: Any] = ["bundleID": bundleID, "visited": cursor, "complete": cursor == queue.count, "nodes": rows]
        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}
