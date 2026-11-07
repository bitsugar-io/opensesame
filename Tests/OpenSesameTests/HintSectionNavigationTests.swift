import AppKit
import ApplicationServices
import Testing
import OpenSesameCore
@testable import OpenSesame

@Test func crowdedWindowOffersSectionsButKeepsMenuNavigationDirect() {
    let controller = Controller()
    let controls = (0..<60).map { index in
        Target(element: AXUIElementCreateApplication(0), frame: CGRect(x: index % 10 * 50, y: index / 10 * 50, width: 24, height: 24),
            label: "unused", kind: .control, action: "AXPress", clicksMenuBarExtra: false,
            metadata: TargetMetadata(role: "AXButton", subrole: "", title: "Action \(index)", description: "", owner: 0, bundleID: "test"))
    }
    let menu = Target(element: AXUIElementCreateApplication(0), frame: CGRect(x: 0, y: 0, width: 20, height: 20),
        label: "unused", kind: .menu, action: "AXPress", clicksMenuBarExtra: false,
        metadata: TargetMetadata(role: "AXMenuBarItem", subrole: "", title: "Apple", description: "", owner: 0, bundleID: "test"))
    let sections = controller.sectionedTargets(controls + [menu], scopedPopup: false)
    #expect(sections.filter { $0.metadata.role == "OpenSesameSection" }.count <= 3)
    #expect(Set(sections.map(\.label)).count == sections.count)
    #expect(sections.last?.metadata.role == "AXMenuBarItem")
    let groupedFrames = sections.flatMap(\.sectionMemberFrames)
    #expect(groupedFrames.count == controls.count)
    #expect(controls.allSatisfy { groupedFrames.contains($0.frame) })
    #expect(!controller.selectSection(sections.last!.label))
    // Discovery of a popup clears old section choices and keeps direct controls.
    let popup = controller.sectionedTargets(controls, scopedPopup: true)
    #expect(popup.count == controls.count)
    #expect(!controller.selectSection(sections[0].label))
}

@Test func nestedSectionsNarrowTheScopeAndBackRestoresTheParentCodes() {
    let controls = (0..<180).map { index in
        Target(element: AXUIElementCreateApplication(0), frame: CGRect(x: index % 15 * 50, y: index / 15 * 50, width: 24, height: 24),
            label: "original\(index)", kind: .control, action: "AXPress", clicksMenuBarExtra: false,
            metadata: TargetMetadata(role: "AXButton", subrole: "", title: "Action \(index)", description: "", owner: 0, bundleID: "test"))
    }
    var navigation = SectionNavigation()
    let root = navigation.reset(controls, scopedPopup: false, configuration: .standard)
    #expect(root.count == 3)
    #expect(navigation.depth == 0)
    #expect(navigation.scopeFrame == nil)
    let movedBack = navigation.back()
    #expect(!movedBack)
    var visited = Set<String>()
    var reachedNestedSection = false
    func visit(_ current: SectionNavigation) {
        let choices = current.targets
        if current.sectionCount == 0 {
            #expect(choices.count <= 18)
            for target in choices { #expect(visited.insert(target.metadata.title).inserted) }
            return
        }
        #expect((2...3).contains(choices.count))
        for choice in choices {
            var child = current
            let selected = child.select(choice.label, configuration: .standard)
            #expect(selected)
            #expect(child.depth == current.depth + 1)
            #expect(child.scopeFrame == choice.frame)
            #expect(child.targets.allSatisfy { choice.frame.contains($0.frame) })
            reachedNestedSection = reachedNestedSection || child.sectionCount > 0
            visit(child)
            let movedBack = child.back()
            #expect(movedBack)
            #expect(child.depth == current.depth)
            #expect(child.scopeFrame == current.scopeFrame)
            #expect(child.targets.map(\.label) == current.targets.map(\.label))
            #expect(child.targets.map(\.frame) == current.targets.map(\.frame))
        }
    }
    visit(navigation)
    #expect(reachedNestedSection)
    #expect(visited == Set(controls.map { $0.metadata.title }))
    let selected = navigation.select(root[0].label, configuration: .standard)
    #expect(selected)
    navigation.clear()
    #expect(navigation.depth == 0 && navigation.targets.isEmpty)
    let selectedAfterClear = navigation.select(root[0].label, configuration: .standard)
    #expect(!selectedAfterClear)
}

@Test func sparsePagesAndPopupsStayDirectAndConfiguredLetterCodesSurviveEveryLevel() throws {
    let controls = (0..<60).map { index in
        Target(element: AXUIElementCreateApplication(0), frame: CGRect(x: index % 10 * 50, y: index / 10 * 50, width: 24, height: 24),
            label: "original\(index)", kind: .control, action: "AXPress", clicksMenuBarExtra: false,
            metadata: TargetMetadata(role: "AXButton", subrole: "", title: "Action \(index)", description: "", owner: 0, bundleID: "test"))
    }
    var navigation = SectionNavigation()
    let config = try HintConfiguration(minimumLength: 3, alphabet: "jk", prefix: "go")
    let sparse = navigation.reset(Array(controls.prefix(20)), scopedPopup: false, configuration: config)
    #expect(sparse.map(\.label) == controls.prefix(20).map(\.label))
    let root = navigation.reset(controls, scopedPopup: false, configuration: config)
    #expect(root.allSatisfy { $0.label.hasPrefix("go") })
    let selected = navigation.select(root[0].label, configuration: config)
    #expect(selected)
    #expect(navigation.targets.allSatisfy { $0.label.hasPrefix("go") })
    let popup = navigation.reset(controls, scopedPopup: true, configuration: config)
    #expect(popup.map(\.label) == controls.map(\.label))
    #expect(navigation.depth == 0 && navigation.sectionCount == 0)
    let movedBack = navigation.back()
    #expect(!movedBack)
}

@Test func inseparableCrowdedControlsUseTheActionPanelInsteadOfConnectorSprawl() {
    let controls = (0..<60).map { index in
        Target(element: AXUIElementCreateApplication(0), frame: CGRect(x: 40, y: 40, width: 400, height: 300),
            label: "original\(index)", kind: .control, action: "AXPress", clicksMenuBarExtra: false,
            metadata: TargetMetadata(role: "AXButton", subrole: "", title: "Action \(index)", description: "", owner: 0, bundleID: "test"))
    }
    var navigation = SectionNavigation()
    _ = navigation.reset(controls, scopedPopup: false, configuration: .standard)
    #expect(navigation.sectionCount == 0)
    #expect(navigation.prefersActionPanel)
    #expect(navigation.targets.count == controls.count)
}

@Test func sectionsExcludeWindowTabsAndBackRestoresThem() throws {
    func target(_ index: Int, tab: Bool) -> Target {
        Target(element: AXUIElementCreateApplication(0),
            frame: CGRect(x: tab ? index * 50 : index % 15 * 50, y: tab ? 0 : 70 + index / 15 * 50, width: 32, height: 24),
            label: "original\(index)", kind: tab ? .tab : .control, action: "AXPress", clicksMenuBarExtra: false,
            metadata: TargetMetadata(role: tab ? "AXRadioButton" : "AXButton", subrole: "", title: "\(tab ? "Tab" : "Action") \(index)",
                description: "", owner: 0, bundleID: "test"))
    }
    let controls = (0..<180).map { target($0, tab: false) }
    let tabs = (0..<19).map { target($0, tab: true) }
    let config = try HintConfiguration(minimumLength: 2, alphabet: "jk", prefix: "go")
    var navigation = SectionNavigation()
    _ = navigation.reset(controls + tabs, scopedPopup: false, configuration: config)
    var visited: [String] = []
    func visit(_ current: SectionNavigation) {
        let choices = current.targets
        #expect(choices.filter { $0.kind == .tab }.map(\.metadata.title) == (current.depth == 0 ? tabs.map(\.metadata.title) : []))
        #expect(current.regionTargets.allSatisfy { $0.kind != .tab })
        let labels = choices.map(\.label)
        #expect(Set(labels).count == labels.count)
        #expect(labels.allSatisfy { label in label.hasPrefix("go") && labels.allSatisfy { $0 == label || !$0.hasPrefix(label) } })
        if current.sectionCount == 0 { visited += current.regionTargets.map(\.metadata.title) }
        for section in choices where section.metadata.role == "OpenSesameSection" {
            var child = current
            #expect(child.select(section.label, configuration: config) == true)
            visit(child)
            #expect(child.back() == true)
            #expect(child.targets.map(\.label) == labels)
            #expect(child.targets.map(\.frame) == choices.map(\.frame))
        }
        var same = current
        if let tab = choices.first(where: { $0.kind == .tab }) {
            #expect(same.select(tab.label, configuration: config) == false)
        }
    }
    visit(navigation)
    #expect(visited.count == controls.count && Set(visited) == Set(controls.map(\.metadata.title)))
    _ = navigation.reset(controls, scopedPopup: true, configuration: config)
    #expect(navigation.targets.allSatisfy { $0.kind != .tab })
}
