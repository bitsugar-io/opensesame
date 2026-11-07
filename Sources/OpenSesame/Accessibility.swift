import AppKit
import ApplicationServices
import OpenSesameCore

struct TargetMetadata {
    let role: String, subrole: String, title: String, description: String
    let owner: pid_t
    let bundleID: String
    var visibleFrames: [CGRect]? = nil
    var windowID: UInt32? = nil
    var identifier = ""
    var isDisclosure = false
    var iconData: Data? = nil
}
struct DiscoveryResult {
    var targets: [Target]
    let scopeFrame: CGRect?
    let placementFrame: CGRect?
    let rootRoles: [String]
    let rejected: [[String: Any]]
    let visitedNodes: Int
    let reachedLimit: Bool
    let elapsed: TimeInterval
    let textFrames: [CGRect]
    let accessibilityPreparation: [String: Int]
    let rootProbes: [[String: Any]]
    let rootResolution: String
    var window: DiscoveredWindow? = nil
}
struct DiscoveredWindow {
    let element: AXUIElement
    let frame: CGRect
    let title: String
    let identifier: String
}
struct Target {
    let element: AXUIElement
    let frame: CGRect // Accessibility uses global, top-left screen coordinates.
    let label: String
    let kind: TargetKind
    let action: String
    let clicksMenuBarExtra: Bool
    var metadata: TargetMetadata
    var sectionMemberFrames: [CGRect] = []
}
func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
    var result: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, key as CFString, &result) == .success else { return nil }
    return result
}
func elementFrame(_ element: AXUIElement) -> CGRect? {
    guard let p = attribute(element, kAXPositionAttribute), CFGetTypeID(p) == AXValueGetTypeID(),
          let s = attribute(element, kAXSizeAttribute), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
    var point = CGPoint.zero, size = CGSize.zero
    guard AXValueGetValue(p as! AXValue, .cgPoint, &point), AXValueGetValue(s as! AXValue, .cgSize, &size),
          size.width > 2, size.height > 2 else { return nil }
    return CGRect(origin: point, size: size)
}
enum Discovery {
    static func closedSurfaceRoots(app: AXUIElement, popupOnly: Bool, menuBarFallback: Bool,
                                   read: (AXUIElement, String) -> CFTypeRef? = attribute) -> (window: AXUIElement?, menu: AXUIElement?) {
        guard !popupOnly || menuBarFallback else { return (nil, nil) }
        func element(_ key: String) -> AXUIElement? {
            guard let value = read(app, key), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
            return value as! AXUIElement
        }
        return (popupOnly ? nil : element(kAXFocusedWindowAttribute), element(kAXMenuBarAttribute))
    }
    static func primaryAction(in actions: [String]) -> String? {
        AccessibilityActionPolicy.primary(role: "", kind: .control, advertised: actions)
    }
    static func scan(pid: pid_t, extras: [pid_t], screens: [CGRect], surface: Surface? = nil, openedFrom: AXUIElement? = nil, configuration: HintConfiguration = .standard, accessibilityAttempt: Int = 0, preparation: [String: Int] = [:], popupOnly: Bool = false, menuBarFallback: Bool = false, windowOwners: Set<pid_t>? = nil, requestedWindow: AXUIElement? = nil) -> DiscoveryResult {
        let started = Date()
        let deadline = started.addingTimeInterval(4)
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.08)
        let isSpotify = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == "com.spotify.client"
        var preparation = preparation
        if accessibilityAttempt == 0 {
            preparation.merge(AccessibilityPreparation.enableTree(app)) { _, fresh in fresh }
        }
        // Chromium initializes its renderer tree asynchronously. Request it before
        // traversal, and preserve the actual AX result codes for diagnostics.
        if isSpotify, accessibilityAttempt == 0 {
            for key in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
                if preparation[key] != nil { continue }
                preparation[key] = Int(AXUIElementSetAttributeValue(app, key as CFString, kCFBooleanTrue).rawValue)
            }
        }
        var rootProbes: [[String: Any]] = []
        var rootResolution = "opened-surface"
        func rootAttribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
            var value: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(element, key as CFString, &value)
            rootProbes.append(["attribute": key, "error": error.rawValue])
            return error == .success ? value : nil
        }
        var roots: [(AXUIElement, Bool)] = []
        var pendingExtras: [pid_t] = []
        var scopeFrame = surface?.frame
        var windowFrame: CGRect?
        var currentWindow: AXUIElement?
        if let requestedWindow {
            // Recall scans this exact window, not whichever app happens to be frontmost.
            currentWindow = requestedWindow
            windowFrame = elementFrame(requestedWindow)
            roots = windowFrame == nil ? [] : [(requestedWindow, false)]
            rootResolution = "saved-window"
        } else if let surface {
            let popupApp = AXUIElementCreateApplication(surface.pid)
            AXUIElementSetMessagingTimeout(popupApp, 0.08)
            let windows = rootAttribute(popupApp, kAXWindowsAttribute) as? [AXUIElement] ?? []
            if let root = surfaceRoot(app: popupApp, windows: windows, surface: surface.frame,
                                      openedFrom: openedFrom, deadline: deadline) {
                roots = [(root, false)]
                rootResolution = "matched-opened-surface"
            } else { rootResolution = "unmatched-menu-surface" }
            // Never scan the complete app menu tree when the opened surface
            // cannot be identified. Stale submenu coordinates can overlap it.
        } else {
            switch currentMenu(app: app, pid: pid, extras: extras, deadline: deadline) {
            case .open(let menu, let menuSurface):
                rootResolution = "matched-menu-or-popup"
                roots = [(menu, false)]
                scopeFrame = menuSurface.frame
            case .unavailable:
                rootResolution = "unmatched-menu-surface"
                // A system popup may expose AXWindow even at the menu layer.
                // Never substitute unrelated controls behind an unmatched menu.
                if let popup = currentSystemPopup(extras: extras, deadline: deadline) {
                    roots = [(popup.0, false)]
                    scopeFrame = popup.1.frame
                }
            case .closed:
                rootResolution = "active-window"
                if let popup = currentSystemPopup(extras: extras, deadline: deadline) {
                    roots = [(popup.0, false)]
                    scopeFrame = popup.1.frame
                } else if let popup = shownPopup(app: app, openedFrom: openedFrom, deadline: deadline) {
                    roots = [(popup, false)]
                    scopeFrame = elementFrame(popup)
                    rootResolution = "shown-popup-in-window"
                } else if !popupOnly || menuBarFallback {
                    let fallback = closedSurfaceRoots(app: app, popupOnly: popupOnly, menuBarFallback: menuBarFallback, read: rootAttribute)
                    if let element = fallback.window {
                        currentWindow = element
                        windowFrame = elementFrame(element)
                        roots.append((element, false))
                    }
                    if let menu = fallback.menu { roots.append((menu, false)) }
                    pendingExtras = extras
                    if popupOnly { rootResolution = "menu-bar-refresh" }
                }
            }
        }
        var rootOwners = Set([pid])
        for (root, _) in roots {
            var rootPID: pid_t = 0
            guard AXUIElementGetPid(root, &rootPID) == .success, rootOwners.insert(rootPID).inserted else { continue }
            if accessibilityAttempt == 0 {
                let provider = AXUIElementCreateApplication(rootPID)
                AXUIElementSetMessagingTimeout(provider, 0.08)
                for (key, result) in AccessibilityPreparation.enableTree(provider) { preparation["\(rootPID):\(key)"] = result }
            }
        }
        var stack = roots.reversed().map { ($0.0, $0.1, false, attribute($0.0, kAXRoleAttribute) as? String == kAXWindowRole, false) }, visited: [CFHashCode: [AXUIElement]] = [:], found: [(AXUIElement, CGRect, Bool, String, TargetKind, TargetMetadata)] = []
        var identities = Set<TargetIdentity>()
        var menuRows: [MenuRow] = []
        var rejected: [[String: Any]] = []
        var excludedChrome: [AXUIElement] = []
        var chromeFrames: [CGRect] = []
        var textFrames: [CGRect] = []
        var nodes = 0
        var bundleIDs: [pid_t: String] = [:]
        // Window selectors cover every allowed app on the current desktop;
        // control traversal remains scoped to the focused window or popup.
        if scopeFrame == nil, rootResolution == "active-window", !popupOnly {
            let surfaces = visibleSurfaces()
            let windows = WindowDiscovery.targets(surfaces: surfaces, owners: windowOwners ?? [pid],
                screens: screens, deadline: deadline, currentWindow: currentWindow)
            found += windows.map { ($0.element, $0.frame, false, $0.action, $0.kind, $0.metadata) }
            let desktop = DesktopDiscovery.targets(owners: windowOwners ?? [pid], screens: screens,
                occluders: surfaces.filter { $0.layer == 0 }.map(\.frame), deadline: min(deadline, Date().addingTimeInterval(0.4)))
            found += desktop.map { ($0.element, $0.frame, false, $0.action, $0.kind, $0.metadata) }
        }
        while nodes < 6000, found.count < 2000, Date() < deadline {
            // Discover window content before spending the scan budget querying
            // every background app's status menu.
            if stack.isEmpty {
                guard !pendingExtras.isEmpty else { break }
                let other = AXUIElementCreateApplication(pendingExtras.removeFirst())
                AXUIElementSetMessagingTimeout(other, 0.08)
                if let menu = attribute(other, "AXExtrasMenuBar") {
                    let root = menu as! AXUIElement
                    roots.append((root, true))
                    stack.append((root, true, false, false, false))
                }
                continue
            }
            guard let (element, isExtra, insideMenuRow, insideWindow, webAncestor) = stack.popLast() else { break }
            nodes += 1
            let hash = CFHash(element)
            guard !(visited[hash] ?? []).contains(where: { CFEqual($0, element) }) else { continue }
            visited[hash, default: []].append(element)
            if attribute(element, kAXHiddenAttribute) as? Bool == true { continue }
            let role = attribute(element, kAXRoleAttribute) as? String ?? ""
            let insideWebContent = webAncestor || role == "AXWebArea"
            if role == kAXWindowRole {
                // Providers can omit subroles or descriptions on traffic lights.
                // Identify them through the owning window's explicit attributes.
                for key in [kAXCloseButtonAttribute, kAXMinimizeButtonAttribute, kAXZoomButtonAttribute, "AXFullScreenButton"] {
                    if let value = attribute(element, key), CFGetTypeID(value) == AXUIElementGetTypeID() {
                        let chrome = value as! AXUIElement
                        excludedChrome.append(chrome)
                        if let frame = elementFrame(chrome) { chromeFrames.append(frame) }
                    }
                }
            }
            if excludedChrome.contains(where: { CFEqual($0, element) }) { continue }
            if role == kAXButtonRole, let frame = elementFrame(element), chromeFrames.contains(where: { TargetGeometry.isStable(previous: $0, current: frame) }) { continue }
            if MenuTraversal.descendsInto(role: role) || role == kAXMenuItemRole {
                let children = AccessibilityTraversal.children(of: element, role: role)
                if children.isEmpty, [kAXGroupRole, kAXWindowRole, "AXWebArea"].contains(role), rejected.count < 512 {
                    var supported: CFArray?
                    AXUIElementCopyAttributeNames(element, &supported)
                    rejected.append(["role": role, "reason": "empty-accessibility-container", "attributes": supported as? [String] ?? []])
                }
                let embedded = insideMenuRow || role == kAXMenuItemRole
                let eligible = embedded ? children.filter {
                    let childRole = attribute($0, kAXRoleAttribute) as? String ?? ""
                    let allowed = MenuTraversal.allowsEmbedded(role: childRole)
                    if !allowed, [kAXStaticTextRole, kAXImageRole].contains(childRole),
                       let frame = elementFrame($0), screens.contains(where: { $0.intersects(frame) }) {
                        textFrames.append(frame)
                    }
                    if !allowed, rejected.count < 512 {
                        rejected.append(["role": childRole, "reason": "pruned-menu-descendant"])
                    }
                    return allowed
                } : children
                stack.append(contentsOf: eligible.reversed().map { ($0, isExtra, embedded, insideWindow, insideWebContent) })
            }
            guard let frame = elementFrame(element), screens.contains(where: { $0.intersects(frame) }) else { continue }
            if insideWindow, let windowFrame, !TargetGeometry.isVisible(frame: frame, viewport: windowFrame) { continue }
            if let scopeFrame, !scopeFrame.insetBy(dx: -2, dy: -2).contains(CGPoint(x: frame.midX, y: frame.midY)) { continue }
            if [kAXStaticTextRole, kAXImageRole].contains(role) { textFrames.append(frame) }
            if found.contains(where: { $0.4 == .desktop && CFEqual($0.0, element) }) { continue }
            guard WebTargetPolicy.allows(role: role, insideWebContent: insideWebContent) else {
                if rejected.count < 512 { rejected.append(["role": role, "reason": "structural-web-element"]) }
                continue
            }
            var actions: CFArray?
            AXUIElementCopyActionNames(element, &actions)
            let names = actions as? [String] ?? []
            let enabled = attribute(element, kAXEnabledAttribute) as? Bool != false
            // Passive text/images need no title/ancestry/disclosure round trips.
            // Preserve the scan budget for actionable descendants lower down.
            let candidate = primaryAction(in: names) != nil || AccessibilityActionPolicy.mayDisclose(role: role)
            guard enabled, candidate else {
                if rejected.count < 512 {
                    rejected.append(["role": role, "actions": names, "reason": enabled ? "no-supported-action" : "disabled",
                                     "frame": ["x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height]])
                }
                continue
            }
            let subrole = attribute(element, kAXSubroleAttribute) as? String ?? ""
            let description = attribute(element, kAXDescriptionAttribute) as? String ?? ""
            let title = attribute(element, kAXTitleAttribute) as? String ?? ""
            let identifier = attribute(element, kAXIdentifierAttribute) as? String ?? ""
            let parentRole: String
            if let parent = attribute(element, kAXParentAttribute) {
                parentRole = attribute(parent as! AXUIElement, kAXRoleAttribute) as? String ?? ""
            } else { parentRole = "" }
            let kind = TargetKind.classify(role: role, subrole: subrole, parentRole: parentRole, description: description)
            guard let plan = AccessibilityActions.plan(element, role: role, kind: kind, advertised: names) else {
                if rejected.count < 512 { rejected.append(["role": role, "actions": names, "reason": "no-supported-primary-action"]) }
                continue
            }
            let action = plan.action
            var elementPID: pid_t = 0
            AXUIElementGetPid(element, &elementPID)
            if bundleIDs[elementPID] == nil { bundleIDs[elementPID] = NSRunningApplication(processIdentifier: elementPID)?.bundleIdentifier ?? "" }
            guard !TargetExclusion.excludes(role: role, subrole: subrole, title: title, description: description, kind: kind,
                                           bundleID: bundleIDs[elementPID] ?? "", action: action) else { continue }
            if ["AXButton", "AXCell"].contains(role) {
                let name = title.isEmpty ? description : title
                if let duplicate = found.firstIndex(where: { existing in
                    let other = existing.5
                    guard Set([role, other.role]) == Set(["AXButton", "AXCell"]),
                          !name.isEmpty, name == (other.title.isEmpty ? other.description : other.title) else { return false }
                    return ActionDuplicate.matches(owner: elementPID, otherOwner: other.owner,
                        name: name, otherName: other.title.isEmpty ? other.description : other.title,
                        frame: frame, otherFrame: existing.1,
                        related: isAncestor(element, of: existing.0) || isAncestor(existing.0, of: element))
                }) {
                    if role == "AXCell" { continue }
                    found.remove(at: duplicate)
                }
            }
            if role == kAXMenuItemRole {
                let row = MenuRow(owner: elementPID, frame: frame)
                guard !menuRows.contains(where: { $0.sharesVisibleRow(with: row) }) else { continue }
                menuRows.append(row)
            }
            let identity = TargetIdentity(pid: elementPID, role: role, name: "\(title)\u{0}\(description)\u{0}\(identifier)", action: action, kind: kind,
                                          x: Double(frame.minX), y: Double(frame.minY), width: Double(frame.width), height: Double(frame.height))
            guard identities.insert(identity).inserted else { continue }
            found.append((element, frame, isExtra, action, kind,
                          TargetMetadata(role: role, subrole: subrole, title: title, description: description, owner: elementPID, bundleID: bundleIDs[elementPID] ?? "", identifier: identifier, isDisclosure: plan.isDisclosure)))
        }
        found.sort {
            if ($0.4 == .window) != ($1.4 == .window) { return $0.4 == .window }
            if $0.4 == .window, $0.1.midX != $1.1.midX { return $0.1.midX < $1.1.midX }
            return $0.1.minY != $1.1.minY ? $0.1.minY < $1.1.minY : $0.1.minX < $1.1.minX
        }
        let missingSpotifyContent = isSpotify && !found.contains(where: { $0.5.owner == pid && $0.5.role != kAXMenuBarItemRole && $0.4 != .window })
        let awaitingPreparedTree = preparation.contains { $0.key.hasSuffix("AXEnhancedUserInterface") && $0.value == Int(AXError.success.rawValue) }
            && !found.contains(where: { rootOwners.contains($0.5.owner) && $0.5.role != kAXMenuBarItemRole && $0.4 != .window })
        let transientRootFailure = roots.isEmpty && rootProbes.contains { ($0["error"] as? Int32) == AXError.cannotComplete.rawValue }
        if (missingSpotifyContent || awaitingPreparedTree || transientRootFailure), accessibilityAttempt < 2,
           Date().timeIntervalSince(started) < 1 {
            // Only the discovery worker waits; the keyboard event tap stays free.
            Thread.sleep(forTimeInterval: 0.2)
            return scan(pid: pid, extras: extras, screens: screens, surface: surface, openedFrom: openedFrom,
                        configuration: configuration, accessibilityAttempt: accessibilityAttempt + 1, preparation: preparation, popupOnly: popupOnly, menuBarFallback: menuBarFallback, windowOwners: windowOwners, requestedWindow: requestedWindow)
        }
        preparation["attempts"] = accessibilityAttempt + 1
        let labels = scopeFrame == nil ? Hints.labels(count: found.count, configuration: configuration)
            : LedgerLayout.labels(frames: found.map { $0.1 }, configuration: configuration)
        let targets = zip(found, labels).map {
            Target(element: $0.0.0, frame: $0.0.1, label: $0.1, kind: $0.0.4, action: $0.0.3,
                   clicksMenuBarExtra: $0.0.2, metadata: $0.0.5)
        }
        let rootRoles = roots.map { attribute($0.0, kAXRoleAttribute) as? String ?? "unknown" }
        return DiscoveryResult(targets: targets, scopeFrame: scopeFrame, placementFrame: scopeFrame ?? windowFrame, rootRoles: rootRoles,
                               rejected: rejected, visitedNodes: nodes, reachedLimit: nodes >= 6000 || found.count >= 2000 || Date() >= deadline,
                               elapsed: Date().timeIntervalSince(started), textFrames: textFrames, accessibilityPreparation: preparation, rootProbes: rootProbes, rootResolution: rootResolution,
                               window: currentWindow.flatMap { window in windowFrame.map {
                                   DiscoveredWindow(element: window, frame: $0, title: attribute(window, kAXTitleAttribute) as? String ?? "",
                                                    identifier: attribute(window, kAXIdentifierAttribute) as? String ?? "")
                               } })
    }
}


func isAncestor(_ ancestor: AXUIElement, of element: AXUIElement, maximumDepth: Int = 6,
                read: (AXUIElement, String) -> CFTypeRef? = attribute) -> Bool {
    var current = element
    for _ in 0..<maximumDepth {
        guard let parent = read(current, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() else { return false }
        current = parent as! AXUIElement
        if CFEqual(current, ancestor) { return true }
    }
    return false
}

// Status-item utilities can expose AXPress yet ignore it. Click these explicit
// targets once, rather than trying AXPress first and accidentally toggling twice.
func clickPrimaryTarget(at point: CGPoint) -> Bool {
    guard let source = CGEventSource(stateID: .hidSystemState),
          let move = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left),
          let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
          let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) else { return false }
    for event in [move, down, up] {
        event.setIntegerValueField(.eventSourceUserData, value: 0x4F534D45)
        event.flags = [] // A shifted hint must not turn into a modified click.
        event.post(tap: .cghidEventTap)
    }
    return true
}

func approximatelyEqual(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
    // AX and WindowServer can disagree about the title bar or shadow bounds.
    guard lhs.width > 0, lhs.height > 0, rhs.width > 0, rhs.height > 0 else { return false }
    let shared = lhs.intersection(rhs)
    let overlap = max(0, shared.width) * max(0, shared.height)
    return overlap / max(lhs.width * lhs.height, rhs.width * rhs.height) > 0.8
}

func visibleSurfaces() -> [Surface] {
    let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    return info.compactMap { row in
        guard let id = row[kCGWindowNumber as String] as? UInt32,
              let pid = row[kCGWindowOwnerPID as String] as? Int32,
              pid != ProcessInfo.processInfo.processIdentifier,
              let bounds = row[kCGWindowBounds as String] as? NSDictionary,
              let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
              (row[kCGWindowAlpha as String] as? Double ?? 1) > 0 else { return nil }
        return Surface(id: id, pid: pid, frame: frame, layer: row[kCGWindowLayer as String] as? Int ?? 0)
    }
}

/// Fresh summons and post-action scans use the same scoped root resolver.
/// Context menus can be direct application children, unrelated to the menu bar.
func surfaceRoot(app: AXUIElement, windows: [AXUIElement], surface: CGRect,
                         openedFrom: AXUIElement?, deadline: Date,
                         read: (AXUIElement, String) -> CFTypeRef? = attribute,
                         frame: (AXUIElement) -> CGRect? = elementFrame,
                         hitTest: (AXUIElement, CGPoint) -> AXUIElement? = { app, point in
                             var element: AXUIElement?
                             return AXUIElementCopyElementAtPosition(app, Float(point.x), Float(point.y), &element) == .success ? element : nil
                         }) -> AXUIElement? {
    if let window = windows.first(where: { frame($0).map { approximatelyEqual($0, surface) } ?? false }) { return window }
    // Some native context menus are absent from application/window children.
    // Read at the known menu surface, then validate the menu ancestor's bounds.
    // This is an AX hit test, never a click or a substitute background target.
    for point in [CGPoint(x: surface.midX, y: surface.midY), CGPoint(x: surface.minX + 12, y: surface.minY + 12)] {
        guard Date() < deadline else { return nil }
        guard var element = hitTest(app, point) else { continue }
        for _ in 0..<8 {
            guard Date() < deadline, read(element, kAXHiddenAttribute) as? Bool != true else { break }
            if read(element, kAXRoleAttribute) as? String == kAXMenuRole,
               let rect = frame(element), approximatelyEqual(rect, surface) { return element }
            guard let parent = read(element, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
            element = parent as! AXUIElement
        }
    }
    var roots: [AXUIElement] = []
    if let openedFrom { roots.append(openedFrom) }
    for key in [kAXFocusedUIElementAttribute, kAXFocusedWindowAttribute, kAXMenuBarAttribute, "AXExtrasMenuBar"] {
        if let value = read(app, key), CFGetTypeID(value) == AXUIElementGetTypeID() {
            var element = value as! AXUIElement
            roots.append(element)
            if key == kAXFocusedUIElementAttribute {
                for _ in 0..<8 {
                    guard Date() < deadline, let parent = read(element, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
                    element = parent as! AXUIElement
                    roots.append(element)
                }
            }
        }
    }
    // Native context menus often live directly on AXApplication rather than
    // AXFocusedUIElement. Search only for a menu matching this on-screen surface.
    roots.append(app)
    return matchingMenu(in: roots, surface: surface, deadline: deadline, read: read, frame: frame)
}

/// Recognize menus/dialogs exposed within an existing AXWindow after an action.
/// Never use an ordinary focused control or the whole window as a substitute.
func shownPopup(app: AXUIElement, openedFrom: AXUIElement?, deadline: Date,
                read: (AXUIElement, String) -> CFTypeRef? = attribute,
                frame: (AXUIElement) -> CGRect? = elementFrame) -> AXUIElement? {
    var seeds: [(AXUIElement, Bool)] = [(app, false)]
    if let openedFrom { seeds.insert((openedFrom, false), at: 0) }
    if let focused = read(app, kAXFocusedUIElementAttribute), CFGetTypeID(focused) == AXUIElementGetTypeID() { seeds.append((focused as! AXUIElement, true)) }
    for (seed, followsFocus) in seeds {
        var element = seed
        for _ in 0..<8 {
            guard Date() < deadline else { return nil }
            if let shown = read(element, kAXShownMenuUIElementAttribute), CFGetTypeID(shown) == AXUIElementGetTypeID() {
                let menu = shown as! AXUIElement
                if read(menu, kAXHiddenAttribute) as? Bool != true, frame(menu) != nil { return menu }
            }
            let role = read(element, kAXRoleAttribute) as? String ?? ""
            let subrole = read(element, kAXSubroleAttribute) as? String ?? ""
            if followsFocus && (["AXMenu", "AXDialog", "AXSheet"].contains(role) || subrole == "AXDialog") {
                if read(element, kAXHiddenAttribute) as? Bool != true, frame(element) != nil { return element }
            }
            // A clicked menu item can retain stale parent coordinates after it
            // closes. Only the *current focus* may identify a popup by ancestry.
            guard followsFocus, let parent = read(element, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
            element = parent as! AXUIElement
        }
    }
    return nil
}

private func matchingMenu(in roots: [AXUIElement], surface: CGRect, deadline: Date,
                          read: (AXUIElement, String) -> CFTypeRef? = attribute,
                          frame: (AXUIElement) -> CGRect? = elementFrame) -> AXUIElement? {
    var stack = roots.map { ($0, 0) }
    var cursor = 0
    var visited: [CFHashCode: [AXUIElement]] = [:]
    var count = 0
    while cursor < stack.count, count < 600, Date() < deadline {
        let (element, depth) = stack[cursor]; cursor += 1
        count += 1
        let hash = CFHash(element)
        guard !(visited[hash] ?? []).contains(where: { CFEqual($0, element) }) else { continue }
        visited[hash, default: []].append(element)
        guard read(element, kAXHiddenAttribute) as? Bool != true else { continue }
        let role = read(element, kAXRoleAttribute) as? String ?? ""
        if role == kAXMenuRole, let frame = frame(element), approximatelyEqual(frame, surface) { return element }
        if let shown = read(element, kAXShownMenuUIElementAttribute), CFGetTypeID(shown) == AXUIElementGetTypeID() {
            let menu = shown as! AXUIElement
            if let frame = frame(menu), approximatelyEqual(frame, surface), read(menu, kAXHiddenAttribute) as? Bool != true { return menu }
        }
        if depth < 8 {
            // Some providers return an empty VisibleChildren array even while
            // their context menu is present in Children. Visit both, deduped by
            // the bounded search rather than treating empty as authoritative.
            let visible = read(element, kAXVisibleChildrenAttribute) as? [AXUIElement] ?? []
            let children = read(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
            stack.append(contentsOf: (visible + children).map { ($0, depth + 1) })
        }
    }
    return nil
}

// Control Center popovers need not become the frontmost app or use AXMenu.
// Recognize only visible windows owned by this known system popup provider.
private func currentSystemPopup(extras: [pid_t], deadline: Date) -> (AXUIElement, Surface)? {
    let owners = Set(extras.filter { NSRunningApplication(processIdentifier: $0)?.bundleIdentifier == "com.apple.controlcenter" })
    let candidates = visibleSurfaces().filter { owners.contains($0.pid) && $0.frame.height > 44 && $0.frame.width > 44 }
    let probeDeadline = min(deadline, Date().addingTimeInterval(0.65))
    for surface in candidates {
        guard Date() < probeDeadline else { break }
        let app = AXUIElementCreateApplication(surface.pid)
        AXUIElementSetMessagingTimeout(app, 0.08)
        let windows = attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? []
        if let window = windows.first(where: { elementFrame($0).map { approximatelyEqual($0, surface.frame) } ?? false }),
           hasExposedPopupControl(window, deadline: probeDeadline) {
            return (window, surface)
        }
    }
    return nil
}

/// Transparent popup hosts may remain in WindowServer and AX after closing.
/// Require a real exposed control, not merely the host window's old rectangle.
func hasExposedPopupControl(_ root: AXUIElement, deadline: Date,
                           read: (AXUIElement, String) -> CFTypeRef? = attribute,
                           frame: (AXUIElement) -> CGRect? = elementFrame,
                           hit: (CGPoint) -> AXUIElement? = { point in
                               var element: AXUIElement?
                               return AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &element) == .success ? element : nil
                           }) -> Bool {
    var queue = [root], cursor = 0, seen = Set<CFHashCode>()
    while cursor < queue.count, cursor < 96, Date() < deadline {
        let element = queue[cursor]; cursor += 1
        guard seen.insert(CFHash(element)).inserted, read(element, kAXHiddenAttribute) as? Bool != true else { continue }
        let role = read(element, kAXRoleAttribute) as? String ?? ""
        if ["AXButton", "AXCheckBox", "AXRadioButton", "AXSlider", "AXMenuItem"].contains(role),
           let rect = frame(element), var exposed = hit(CGPoint(x: rect.midX, y: rect.midY)) {
            for _ in 0..<8 {
                if CFEqual(exposed, root) { return true }
                guard let parent = read(exposed, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
                exposed = parent as! AXUIElement
            }
        }
        queue += read(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }
    return false
}

/// Menu-level windows also include passive banners. A matching window frame
/// alone must not steal discovery from the active app.
func hasPopupControls(_ root: AXUIElement, deadline: Date,
                      read: (AXUIElement, String) -> CFTypeRef? = attribute,
                      actions: (AXUIElement) -> [String] = { element in
                          var names: CFArray?
                          guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
                          return names as? [String] ?? []
                      }) -> Bool? {
    var queue = [root], cursor = 0
    var visited = Set<CFHashCode>()
    let controls: Set<String> = ["AXMenuItem", "AXButton", "AXCheckBox", "AXRadioButton", "AXSwitch", "AXLink",
        "AXPopUpButton", "AXMenuButton", "AXSlider", "AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]
    while cursor < queue.count, cursor < 128, Date() < deadline {
        let element = queue[cursor]; cursor += 1
        guard visited.insert(CFHash(element)).inserted, read(element, kAXHiddenAttribute) as? Bool != true else { continue }
        let role = read(element, kAXRoleAttribute) as? String ?? ""
        if controls.contains(role) { return true }
        if role != kAXWindowRole {
            let names = actions(element)
            if names.contains(kAXPressAction) || names.contains(kAXShowMenuAction) { return true }
        }
        queue += read(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }
    return cursor < queue.count ? nil : false
}

private enum CurrentMenu {
    case closed, open(AXUIElement, Surface), unavailable
}

private func currentMenu(app: AXUIElement, pid: pid_t, extras: [pid_t], deadline: Date) -> CurrentMenu {
    // NSStatusItem menus are owned by their extra app even when Ghostty remains
    // frontmost. Only consider owners already allowed by the app-filter settings.
    let menuLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
    let owners = Set(extras + [pid])
    let surfaces = Surface.menus(in: visibleSurfaces(), owners: owners, menuLayer: menuLevel)
    guard !surfaces.isEmpty else { return .closed }
    // Tooltips/help/drag windows are higher than the native menu level and are
    // not menus. Keep even valid menu probes from consuming the whole scan.
    let probeDeadline = min(deadline, Date().addingTimeInterval(0.65))
    var unmatched = false
    for surface in surfaces {
        guard Date() < probeDeadline else { return .unavailable }
        let menuApp = surface.pid == pid ? app : AXUIElementCreateApplication(surface.pid)
        AXUIElementSetMessagingTimeout(menuApp, 0.08)
        let windows = attribute(menuApp, kAXWindowsAttribute) as? [AXUIElement] ?? []
        if let root = surfaceRoot(app: menuApp, windows: windows, surface: surface.frame,
                                  openedFrom: nil, deadline: probeDeadline) {
            if attribute(root, kAXRoleAttribute) as? String != kAXWindowRole || hasPopupControls(root, deadline: probeDeadline) != false {
                return .open(root, surface)
            }
            // Passive notification/decoration windows are not open menus.
            continue
        }
        unmatched = true
    }
    return unmatched ? .unavailable : .closed
}
