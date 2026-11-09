import ApplicationServices
import CoreGraphics
import Testing
import OpenSesameCore
@testable import OpenSesame

@Test func windowChoicesSpanAppsAndKeepTheExposedStripOfBackgroundWindows() {
    let front = CGRect(x: 500, y: 80, width: 600, height: 600)
    let behind = CGRect(x: 500, y: 20, width: 600, height: 700)
    let left = CGRect(x: 0, y: 20, width: 450, height: 700)
    let surfaces = [Surface(id: 1, pid: 11, frame: front), Surface(id: 2, pid: 11, frame: behind), Surface(id: 3, pid: 22, frame: left)]
    var queried: [Int32] = []
    let targets = WindowDiscovery.targets(surfaces: surfaces, owners: [11, 22],
        screens: [CGRect(x: 0, y: 0, width: 1200, height: 800)], deadline: Date().addingTimeInterval(1)) { owner, _ in
        queried.append(owner)
        return surfaces.filter { $0.pid == owner }.map {
            WindowDiscovery.Candidate(element: AXUIElementCreateApplication(owner), frame: $0.frame, title: "Window", bundleID: "test.\(owner)")
        }
    }
    #expect(queried == [11, 22])
    #expect(targets.map { $0.metadata.owner } == [11, 11, 22])
    #expect(targets.map { $0.metadata.windowID } == [1, 2, 3])
    #expect(targets[1].metadata.visibleFrames == [CGRect(x: 500, y: 20, width: 600, height: 60), CGRect(x: 500, y: 680, width: 600, height: 40)])
    #expect(targets.allSatisfy { $0.kind == .window && $0.action == "AXRaise" })
}

@Test func filteredAppsStillOccludeWindowsButAreNotSelectable() {
    let front = CGRect(x: 0, y: 0, width: 600, height: 600)
    let behind = CGRect(x: 0, y: 0, width: 600, height: 700)
    let surfaces = [Surface(id: 1, pid: 11, frame: front), Surface(id: 2, pid: 22, frame: behind)]
    let targets = WindowDiscovery.targets(surfaces: surfaces, owners: [22], screens: [behind], deadline: Date().addingTimeInterval(1)) { owner, _ in
        #expect(owner == 22)
        return [.init(element: AXUIElementCreateApplication(owner), frame: behind, title: "Window", bundleID: "test")]
    }
    #expect(targets.count == 1)
    #expect(targets[0].metadata.visibleFrames == [CGRect(x: 0, y: 600, width: 600, height: 100)])
}

@Test func firstWindowScanIgnoresSystemOverlayCanvasesAndFindsBackgroundApps() {
    let screen = CGRect(x: 0, y: 0, width: 5120, height: 1440)
    let surfaces = [
        // Notification Center publishes this screen-sized canvas at layer 21
        // even when it is transparent. The menu bar lives above it at layer 24.
        Surface(id: 1, pid: 90, frame: CGRect(x: 0, y: 0, width: 5120, height: 30), layer: 24),
        Surface(id: 2, pid: 91, frame: screen, layer: 21),
        Surface(id: 3, pid: 11, frame: CGRect(x: 2464, y: 143, width: 2560, height: 1136)),
        Surface(id: 4, pid: 22, frame: CGRect(x: 0, y: 30, width: 2400, height: 1410)),
        Surface(id: 5, pid: 22, frame: CGRect(x: 2503, y: 30, width: 2280, height: 1410))
    ]
    let targets = WindowDiscovery.targets(surfaces: surfaces, owners: [11, 22], screens: [screen], deadline: Date().addingTimeInterval(1)) { owner, _ in
        surfaces.filter { $0.pid == owner }.map {
            .init(element: AXUIElementCreateApplication(owner), frame: $0.frame, title: "Window", bundleID: "test")
        }
    }
    #expect(targets.map { $0.metadata.windowID } == [3, 4, 5])
    #expect(targets.map { $0.metadata.owner } == [11, 22, 22])
    #expect(targets[1].metadata.visibleFrames == [surfaces[3].frame])
    #expect(targets[2].metadata.visibleFrames == [CGRect(x: 2503, y: 30, width: 2280, height: 113),
                                               CGRect(x: 2503, y: 1279, width: 2280, height: 161)])
}

@Test func fullyCoveredNormalWindowsRemainExcluded() {
    let screen = CGRect(x: 0, y: 0, width: 1200, height: 800)
    let surfaces = [Surface(id: 1, pid: 11, frame: screen),
                    Surface(id: 2, pid: 22, frame: CGRect(x: 100, y: 100, width: 600, height: 600))]
    let targets = WindowDiscovery.targets(surfaces: surfaces, owners: [11, 22], screens: [screen], deadline: Date().addingTimeInterval(1)) { owner, _ in
        surfaces.filter { $0.pid == owner }.map {
            .init(element: AXUIElementCreateApplication(owner), frame: $0.frame, title: "Window", bundleID: "test")
        }
    }
    #expect(targets.map { $0.metadata.windowID } == [1])
}

@Test func currentWindowHasNoRefocusCodeButOtherWindowsOfItsAppStaySelectable() {
    let front = CGRect(x: 500, y: 80, width: 600, height: 600)
    let behind = CGRect(x: 500, y: 20, width: 600, height: 700)
    let left = CGRect(x: 0, y: 20, width: 450, height: 700)
    let surfaces = [Surface(id: 1, pid: 11, frame: front), Surface(id: 2, pid: 11, frame: behind), Surface(id: 3, pid: 22, frame: left)]
    let targets = WindowDiscovery.targets(surfaces: surfaces, owners: [11, 22],
        screens: [CGRect(x: 0, y: 0, width: 1200, height: 800)], deadline: Date().addingTimeInterval(1),
        currentWindow: AXUIElementCreateApplication(1)) { owner, _ in
        surfaces.filter { $0.pid == owner }.map {
            .init(element: AXUIElementCreateApplication(pid_t($0.id)), frame: $0.frame, title: "Window", bundleID: "test")
        }
    }
    #expect(targets.map { $0.metadata.windowID } == [2, 3])
    #expect(targets.map { $0.metadata.owner } == [11, 22])
    // The current window still occludes the background one, even without a code.
    #expect(targets[0].metadata.visibleFrames == [CGRect(x: 500, y: 20, width: 600, height: 60), CGRect(x: 500, y: 680, width: 600, height: 40)])
}
