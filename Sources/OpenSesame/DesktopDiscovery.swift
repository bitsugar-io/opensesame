import AppKit
import ApplicationServices
import OpenSesameCore

enum DesktopDiscovery {
    /// Match Finder's desktop icon surfaces, never an ordinary Finder window
    /// by its localized title. Exposed icons are available regardless of focus.
    static func targets(owners: Set<pid_t>, screens: [CGRect], occluders: [CGRect], deadline: Date) -> [Target] {
        guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first,
              owners.contains(finder.processIdentifier), Date() < deadline else { return [] }
        let pid = finder.processIdentifier
        let rows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        let surfaces = rows.compactMap { row -> CGRect? in
            guard row[kCGWindowOwnerPID as String] as? pid_t == pid,
                  row[kCGWindowLayer as String] as? Int == Int(CGWindowLevelForKey(.desktopIconWindow)),
                  let rect = row[kCGWindowBounds as String] as? NSDictionary else { return nil }
            return CGRect(dictionaryRepresentation: rect as CFDictionary)
        }
        guard !surfaces.isEmpty else { return [] }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.08)
        let windows = (attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? []).compactMap { element in
            elementFrame(element).map { (element, $0) }
        }
        let roots = WindowMatching.matches(windows: windows.map { $0.1 }, surfaces: surfaces).map { windows[$0.window].0 }
        var queue = roots, cursor = 0, seen = Set<CFHashCode>(), result: [Target] = []
        while cursor < queue.count, cursor < 512, Date() < deadline {
            let element = queue[cursor]; cursor += 1
            guard seen.insert(CFHash(element)).inserted, attribute(element, kAXHiddenAttribute) as? Bool != true else { continue }
            let role = attribute(element, kAXRoleAttribute) as? String ?? ""
            queue += AccessibilityTraversal.children(of: element, role: role)
            guard AccessibilityActionPolicy.desktopRoleIsEligible(role), let frame = elementFrame(element),
                  DesktopVisibility.isExposed(frame, screens: screens, occluders: occluders),
                  attribute(element, kAXEnabledAttribute) as? Bool != false else { continue }
            var actions: CFArray?
            AXUIElementCopyActionNames(element, &actions)
            let names = actions as? [String] ?? []
            guard let plan = AccessibilityActions.plan(element, role: role, kind: .desktop, advertised: names) else { continue }
            let metadata = TargetMetadata(role: role, subrole: attribute(element, kAXSubroleAttribute) as? String ?? "",
                title: attribute(element, kAXTitleAttribute) as? String ?? "", description: attribute(element, kAXDescriptionAttribute) as? String ?? "",
                owner: pid, bundleID: "com.apple.finder",
                visibleFrames: DesktopVisibility.exposed(frame, screens: screens, occluders: occluders),
                identifier: attribute(element, kAXIdentifierAttribute) as? String ?? "", isDisclosure: plan.isDisclosure)
            guard !TargetExclusion.excludes(role: role, subrole: metadata.subrole, title: metadata.title,
                description: metadata.description, kind: .desktop, action: plan.action) else { continue }
            result.append(Target(element: element, frame: frame, label: "", kind: .desktop, action: plan.action, clicksMenuBarExtra: false, metadata: metadata))
        }
        return result
    }
}
