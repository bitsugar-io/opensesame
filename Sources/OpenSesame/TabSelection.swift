import AppKit
import ApplicationServices
import OpenSesameCore

enum TabSelection {
    case none, choices, contents
    static let groupClick = AccessibilityActionPolicy.tabGroupClick

    static func action(role: String, advertised: [String]) -> String? {
        AccessibilityActionPolicy.primary(role: role, kind: .tab, advertised: advertised)
    }

    struct ClickResult { let posted: Bool; let reason: String; var details: [String: Any] = [:] }
    static func hitRelationship(target: AXUIElement, hit: AXUIElement, frame: CGRect, owner: pid_t,
                                read: (AXUIElement, String) -> CFTypeRef? = attribute,
                                getFrame: (AXUIElement) -> CGRect? = elementFrame,
                                getOwner: (AXUIElement) -> pid_t = { var pid: pid_t = 0; AXUIElementGetPid($0, &pid); return pid }) -> String? {
        guard getOwner(hit) == owner else { return nil }
        if CFEqual(hit, target) { return "target" }
        if isAncestor(target, of: hit, maximumDepth: 16, read: read) { return "descendant" }
        // Native host views can expose a separate AX branch from the tab strip.
        // Resolve the owning window through either AXWindow or parent links.
        guard ["AXGroup", "AXTabGroup", "AXToolbar"].contains(read(hit, kAXRoleAttribute) as? String ?? ""),
              let hitFrame = getFrame(hit), hitFrame.contains(frame),
              let targetWindow = AccessibilityTraversal.window(of: target, read: read),
              let hitWindow = AccessibilityTraversal.window(of: hit, read: read), CFEqual(targetWindow, hitWindow) else { return nil }
        if isAncestor(hit, of: target, maximumDepth: 16, read: read) { return "ancestor" }
        // Some native tab strips hit-test a sibling host instead of the AX
        // tab tree. The live trace shows both branches under the same parent,
        // with the host covering exactly the tab strip, not the whole window.
        guard read(hit, kAXRoleAttribute) as? String == "AXGroup",
              read(target, kAXRoleAttribute) as? String == "AXTabGroup",
              let stripValue = read(target, kAXParentAttribute), CFGetTypeID(stripValue) == AXUIElementGetTypeID() else { return nil }
        let strip = stripValue as! AXUIElement
        guard read(strip, kAXRoleAttribute) as? String == "AXTabGroup",
              let stripFrame = getFrame(strip), TargetGeometry.isStable(previous: stripFrame, current: hitFrame),
              let stripParent = read(strip, kAXParentAttribute), CFGetTypeID(stripParent) == AXUIElementGetTypeID(),
              let hitParent = read(hit, kAXParentAttribute), CFGetTypeID(hitParent) == AXUIElementGetTypeID(),
              CFEqual(stripParent, hitParent) else { return nil }
        return "tab-strip-host"
    }
    static func hitDiagnostics(target: AXUIElement, hit: AXUIElement) -> [String: Any] {
        let deadline = Date().addingTimeInterval(0.25)
        func chain(_ element: AXUIElement) -> [[String: Any]] {
            var result: [[String: Any]] = [], current = element
            for _ in 0..<16 {
                guard Date() < deadline else { break }
                var row: [String: Any] = ["id": CFHash(current), "role": attribute(current, kAXRoleAttribute) as? String ?? ""]
                if let frame = elementFrame(current) { row["frame"] = ["x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height] }
                if let window = attribute(current, kAXWindowAttribute), CFGetTypeID(window) == AXUIElementGetTypeID() { row["windowID"] = CFHash(window) }
                result.append(row)
                if row["role"] as? String == kAXWindowRole { break }
                guard let parent = attribute(current, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
                current = parent as! AXUIElement
            }
            return result
        }
        return ["targetAncestors": chain(target), "hitAncestors": chain(hit)]
    }
    static func clickGroup(_ target: Target, frame: CGRect) -> ClickResult {
        guard target.kind == .tab, attribute(target.element, kAXRoleAttribute) as? String == "AXTabGroup",
              attribute(target.element, kAXHiddenAttribute) as? Bool != true else {
            return .init(posted: false, reason: "group-role-changed")
        }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.metadata.owner else {
            return .init(posted: false, reason: "group-owner-not-frontmost")
        }
        guard let parent = attribute(target.element, kAXParentAttribute),
              CFGetTypeID(parent) == AXUIElementGetTypeID(),
              attribute(parent as! AXUIElement, kAXRoleAttribute) as? String == "AXTabGroup" else {
            return .init(posted: false, reason: "group-parent-changed")
        }
        let point = CGPoint(x: frame.midX, y: frame.midY)
        var hit: AXUIElement?
        let error = AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &hit)
        guard error == .success, let hit else {
            return .init(posted: false, reason: "group-hit-test-failed", details: ["hitTestError": error.rawValue])
        }
        guard let relationship = hitRelationship(target: target.element, hit: hit, frame: frame, owner: target.metadata.owner) else {
            var hitPID: pid_t = 0; AXUIElementGetPid(hit, &hitPID)
            var details = hitDiagnostics(target: target.element, hit: hit)
            details["hitRole"] = attribute(hit, kAXRoleAttribute) as? String ?? ""; details["hitOwner"] = hitPID
            return .init(posted: false, reason: "group-hit-mismatch", details: details)
        }
        let sent = clickPrimaryTarget(at: point)
        return .init(posted: sent, reason: sent ? "tab-group-click-posted" : "mouse-events-unavailable", details: ["hitRelationship": relationship])
    }
}

extension Controller {
    func refreshAfterTabSelection(_ target: Target) {
        guard let selectedWindow = AccessibilityTraversal.window(of: target.element) else {
            message = "That tab's window is unavailable. Summon fresh hints."; return
        }
        let window = StackWindowResolver.Resolved(owner: target.metadata.owner, element: selectedWindow)
        let ticket = generation
        scanning = true
        syncInputRouting()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, self.lifecycle.accepts(generation: ticket), self.enabled, self.trusted else { return }
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.metadata.owner else {
                self.cancel(reason: "tab-owner-changed"); return
            }
            self.summon(window: window, tabSelection: target.metadata.role == "AXTabGroup" ? .choices : .contents)
        }
    }
}
