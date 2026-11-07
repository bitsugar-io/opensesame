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
        // Some providers hit-test the enclosing native group instead of the
        // tab-strip header. Accept that coarse result only when it is an actual
        // ancestor in the same window, with bounds containing the whole header.
        guard ["AXGroup", "AXTabGroup", "AXToolbar"].contains(read(hit, kAXRoleAttribute) as? String ?? ""),
              isAncestor(hit, of: target, maximumDepth: 16, read: read),
              let hitFrame = getFrame(hit), hitFrame.contains(frame),
              let targetWindow = read(target, kAXWindowAttribute), CFGetTypeID(targetWindow) == AXUIElementGetTypeID(),
              let hitWindow = read(hit, kAXWindowAttribute), CFEqual(targetWindow, hitWindow) else { return nil }
        return "ancestor"
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
            return .init(posted: false, reason: "group-hit-mismatch", details: [
                "hitRole": attribute(hit, kAXRoleAttribute) as? String ?? "", "hitOwner": hitPID])
        }
        let sent = clickPrimaryTarget(at: point)
        return .init(posted: sent, reason: sent ? "tab-group-click-posted" : "mouse-events-unavailable", details: ["hitRelationship": relationship])
    }
}

extension Controller {
    func refreshAfterTabSelection(_ target: Target) {
        guard let rawWindow = attribute(target.element, kAXWindowAttribute), CFGetTypeID(rawWindow) == AXUIElementGetTypeID() else {
            message = "That tab's window is unavailable. Summon fresh hints."; return
        }
        let window = StackWindowResolver.Resolved(owner: target.metadata.owner, element: rawWindow as! AXUIElement)
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
