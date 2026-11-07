import CoreGraphics
import OpenSesameCore

/// Navigation state is independent of overlays and input hooks so drill-down
/// and backtracking can be verified without showing windows or posting input.
struct SectionNavigation {
    private struct Page {
        var targets: [Target] = []
        var members: [Target] = []
        var name = "Window"
        var contents: [String: [Target]] = [:]
        var scope: CGRect?
        var prefersActionPanel = false
        var tabChoices = false
    }
    private var page = Page()
    private var ancestors: [Page] = []
    private var tabs: [Target] = []
    var targets: [Target] { page.targets }
    var regionTargets: [Target] { page.members }
    var regionName: String { page.name }
    var scopeFrame: CGRect? { page.scope }
    var depth: Int { ancestors.filter { !$0.tabChoices }.count }
    var canGoBack: Bool { !ancestors.isEmpty }
    var isChoosingTabs: Bool { page.tabChoices }
    var sectionCount: Int { page.contents.count }
    var prefersActionPanel: Bool { page.prefersActionPanel }

    mutating func clear() { page = Page(); ancestors = []; tabs = [] }

    mutating func reset(_ targets: [Target], scopedPopup: Bool, configuration: HintConfiguration, windowFrame: CGRect? = nil, tabSelection: TabSelection = .none) -> [Target] {
        ancestors = []
        tabs = scopedPopup ? [] : targets.filter { $0.kind == .tab }
        page = scopedPopup ? Page(targets: targets, members: targets) : makePage(targets, threshold: 40, scope: windowFrame, configuration: configuration)
        if !tabs.isEmpty {
            let labels = Hints.labels(count: tabs.count, configuration: configuration)
            let choices = zip(tabs, labels).map { target, code in
                Target(element: target.element, frame: target.frame, label: code, kind: target.kind,
                    action: target.action, clicksMenuBarExtra: target.clicksMenuBarExtra, metadata: target.metadata)
            }
            let tabPage = Page(targets: choices, name: "Tabs", tabChoices: true)
            switch tabSelection {
            case .none: break
            case .choices: page = tabPage
            case .contents: ancestors = [tabPage]
            }
        }
        return page.targets
    }

    mutating func select(_ code: String, configuration: HintConfiguration) -> Bool {
        guard let contents = page.contents[code] else { return false }
        let name = page.targets.first { $0.label == code }?.metadata.title.components(separatedBy: " · ").first ?? "Section"
        ancestors.append(page)
        // Tabs belong to the window level. A section contains only its own
        // controls; Backspace restores the actual parent, including its tabs.
        let choices = contents
        let labels = Hints.labels(count: choices.count, configuration: configuration)
        let relabeled = zip(choices, labels).map { target, label in
            Target(element: target.element, frame: target.frame, label: label, kind: target.kind,
                   action: target.action, clicksMenuBarExtra: target.clicksMenuBarExtra, metadata: target.metadata)
        }
        let scope = page.targets.first { $0.label == code }?.frame ?? contents.reduce(CGRect.null) { $0.union($1.frame) }
        page = makePage(relabeled, threshold: 18, scope: scope, configuration: configuration)
        page.name = name
        return true
    }

    mutating func back() -> Bool {
        guard let previous = ancestors.popLast() else { return false }
        page = previous
        return true
    }

    private func makePage(_ found: [Target], threshold: Int, scope: CGRect?, configuration: HintConfiguration) -> Page {
        let controls = found.filter { $0.kind != .window && $0.kind != .tab && $0.kind != .desktop && $0.metadata.role != "AXMenuBarItem" }
        let sections = HintSections.make(frames: controls.map(\.frame), threshold: threshold, bounds: scope)
        guard !sections.isEmpty else {
            // An inseparable cluster should use one readable list, not an
            // expanding web of detached labels and connector lines.
            return Page(targets: found, members: controls, scope: scope, prefersActionPanel: controls.count > threshold)
        }
        let navigation = found.filter { $0.kind == .window || $0.kind == .tab || $0.kind == .desktop || $0.metadata.role == "AXMenuBarItem" }
        let labels = Hints.labels(count: sections.count + navigation.count, configuration: configuration)
        var result = Page(members: controls, scope: scope)
        let whole = controls.reduce(CGRect.null) { $0.union($1.frame) }
        for (index, section) in sections.enumerated() {
            let contents = section.indices.map { controls[$0] }
            guard let first = contents.first else { continue }
            let label = labels[index]
            result.contents[label] = contents
            let vertical = section.frame.midY < whole.minY + whole.height / 3 ? "Upper" : (section.frame.midY > whole.maxY - whole.height / 3 ? "Lower" : "Middle")
            let horizontal = section.frame.midX < whole.minX + whole.width / 3 ? "left" : (section.frame.midX > whole.maxX - whole.width / 3 ? "right" : "center")
            let metadata = TargetMetadata(role: "OpenSesameSection", subrole: "", title: "\(vertical) \(horizontal) · \(contents.count)",
                description: "", owner: first.metadata.owner, bundleID: first.metadata.bundleID)
            result.targets.append(Target(element: first.element, frame: section.frame, label: label, kind: .control,
                action: "", clicksMenuBarExtra: false, metadata: metadata, sectionMemberFrames: contents.map(\.frame)))
        }
        for (index, target) in navigation.enumerated() {
            result.targets.append(Target(element: target.element, frame: target.frame, label: labels[sections.count + index],
                kind: target.kind, action: target.action, clicksMenuBarExtra: target.clicksMenuBarExtra, metadata: target.metadata))
        }
        return result
    }
}
