import AppKit
import ApplicationServices
import Testing
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
    #expect(sections.count < 10)
    #expect(Set(sections.map(\.label)).count == sections.count)
    #expect(sections.last?.metadata.role == "AXMenuBarItem")
    #expect(!controller.selectSection(sections.last!.label))
    // Discovery of a popup clears old section choices and keeps direct controls.
    let popup = controller.sectionedTargets(controls, scopedPopup: true)
    #expect(popup.count == controls.count)
    #expect(!controller.selectSection(sections[0].label))
}
