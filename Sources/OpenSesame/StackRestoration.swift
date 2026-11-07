import AppKit
import ApplicationServices
import OpenSesameCore

extension SectionNavigation {
    func regionDescription(in window: CGRect) -> String {
        guard let scope = scopeFrame else { return "Window" }
        let x = (scope.midX - window.minX) / max(1, window.width)
        let y = (scope.midY - window.minY) / max(1, window.height)
        let vertical = y < 1.0 / 3 ? "Upper" : (y > 2.0 / 3 ? "Lower" : "Middle")
        let horizontal = x < 1.0 / 3 ? "left" : (x > 2.0 / 3 ? "right" : "center")
        return "\(vertical) \(horizontal)"
    }

    func anchor(in window: CGRect) -> StackRegion {
        StackRegion(anchors: regionTargets.map { target in
            let metadata = target.metadata
            let name = metadata.title.isEmpty ? metadata.description : metadata.title
            return StackAnchor(role: metadata.role, identifier: metadata.identifier, name: name,
                x: (target.frame.midX - window.minX) / max(1, window.width),
                y: (target.frame.midY - window.minY) / max(1, window.height))
        })
    }

    /// Search the freshly discovered section tree, retaining real parents for
    /// Backspace. Hint letters and the old absolute rectangle play no role.
    mutating func restore(_ region: StackRegion, window: CGRect, configuration: HintConfiguration) -> Bool {
        var pending = [self]
        var candidates: [SectionNavigation] = []
        var visited = 0
        while let candidate = pending.popLast(), visited < 512 {
            visited += 1
            candidates.append(candidate)
            for target in candidate.targets where target.metadata.role == "OpenSesameSection" {
                var child = candidate
                if child.select(target.label, configuration: configuration) { pending.append(child) }
            }
        }
        guard let index = region.uniqueMatch(in: candidates.map { $0.anchor(in: window) }) else { return false }
        self = candidates[index]
        return true
    }
}

enum StackWindowResolver {
    struct LiveWindow { let owner: pid_t; let element: AXUIElement }
    struct Resolved { let owner: pid_t; let element: AXUIElement }
    /// A live reference is authoritative: a closed window must never be
    /// replaced by a new window that happens to reuse its title.
    static func resolve(_ saved: StackWindow, live: LiveWindow?, owners: [pid_t],
                        load: (pid_t) -> [AXUIElement],
                        describe: (AXUIElement) -> StackWindow) -> Resolved? {
        if let live {
            guard owners.contains(live.owner), load(live.owner).contains(where: { CFEqual($0, live.element) }) else { return nil }
            return Resolved(owner: live.owner, element: live.element)
        }
        let windows = owners.flatMap { owner in load(owner).map { Resolved(owner: owner, element: $0) } }
        guard let index = saved.uniqueMatch(in: windows.map { describe($0.element) }) else { return nil }
        return windows[index]
    }
}
