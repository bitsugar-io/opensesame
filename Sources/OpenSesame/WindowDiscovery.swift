import AppKit
import ApplicationServices
import OpenSesameCore

enum WindowDiscovery {
    struct Candidate {
        let element: AXUIElement
        let frame: CGRect
        let title: String
        let bundleID: String
    }

    /// Query only window-level AX attributes for background apps. Their tabs
    /// and controls remain outside the current window's hint session.
    static func candidates(owner: pid_t, deadline: Date) -> [Candidate] {
        let app = AXUIElementCreateApplication(owner)
        AXUIElementSetMessagingTimeout(app, 0.08)
        let windows = attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? []
        let bundleID = NSRunningApplication(processIdentifier: owner)?.bundleIdentifier ?? ""
        var result: [Candidate] = []
        for window in windows {
            guard Date() < deadline else { break }
            AXUIElementSetMessagingTimeout(window, 0.08)
            guard attribute(window, kAXMinimizedAttribute) as? Bool != true,
                  attribute(window, kAXHiddenAttribute) as? Bool != true,
                  let frame = elementFrame(window) else { continue }
            let subrole = attribute(window, kAXSubroleAttribute) as? String ?? ""
            guard subrole.isEmpty || subrole == kAXStandardWindowSubrole else { continue }
            var actions: CFArray?
            AXUIElementCopyActionNames(window, &actions)
            guard (actions as? [String] ?? []).contains(kAXRaiseAction) else { continue }
            result.append(Candidate(element: window, frame: frame, title: attribute(window, kAXTitleAttribute) as? String ?? "", bundleID: bundleID))
        }
        return result
    }

    static func targets(surfaces: [Surface], owners: Set<pid_t>, screens: [CGRect], deadline: Date,
                        currentWindow: AXUIElement? = nil,
                        load: (pid_t, Date) -> [Candidate] = candidates) -> [Target] {
        var result: [(order: Int, target: Target)] = []
        var visited = Set<pid_t>()
        for surface in surfaces where surface.layer == 0 && owners.contains(surface.pid) {
            guard Date() < deadline else { break }
            guard visited.insert(surface.pid).inserted else { continue }
            let visible = surfaces.enumerated().filter { $0.element.pid == surface.pid && $0.element.layer == 0 }
            let windows = load(surface.pid, deadline)
            for match in WindowMatching.matches(windows: windows.map(\.frame), surfaces: visible.map { $0.element.frame }) {
                let window = windows[match.window]
                // Its controls/sections are already being navigated. A second
                // centered code would only refocus this window and dismiss
                // hints, competing with the section that contains it.
                if let currentWindow, CFEqual(window.element, currentWindow) { continue }
                let (order, matchedSurface) = visible[match.surface]
                let exposed = VisibleRegion.exposed(frame: window.frame.intersection(matchedSurface.frame), screens: screens,
                    // WindowServer alpha describes the surface, not the pixels
                    // inside it. System overlay canvases can cover the desktop
                    // with alpha 1 while remaining visually transparent. Only
                    // normal app windows occlude other normal window choices.
                    occluders: surfaces[..<order].filter { $0.layer == 0 }.map(\.frame))
                guard exposed.contains(where: { $0.width > 2 && $0.height > 2 }) else { continue }
                let metadata = TargetMetadata(role: kAXWindowRole, subrole: kAXStandardWindowSubrole,
                    title: window.title, description: "Switch window", owner: surface.pid, bundleID: window.bundleID,
                    visibleFrames: exposed, windowID: matchedSurface.id)
                result.append((order, Target(element: window.element, frame: window.frame, label: "", kind: .window,
                    action: kAXRaiseAction, clicksMenuBarExtra: false, metadata: metadata)))
            }
        }
        return result.sorted { $0.order < $1.order }.map(\.target)
    }
}
