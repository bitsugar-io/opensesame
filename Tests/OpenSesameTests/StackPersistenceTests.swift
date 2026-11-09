import AppKit
import ApplicationServices
import Foundation
import Testing
import OpenSesameCore
@testable import OpenSesame

@MainActor
struct StackPersistenceTests {
    @Test func dismissingCandidateDoesNotSaveAndExplicitSavePersistsIt() throws {
        try fixture { url in
            let model = load(url)
            let candidate = StackCandidate(place: place(1), live: .init(owner: 0, element: AXUIElementCreateApplication(0)))
            let before = try String(contentsOf: url, encoding: .utf8)
            model.active = true; model.stackCandidate = candidate
            model.cancel(reason: "escape")
            #expect(model.stacks.places.isEmpty && model.stackCandidate == nil)
            #expect(try String(contentsOf: url, encoding: .utf8) == before)
            try model.saveStack(candidate)
            #expect(load(url).stacks.places.map(\.id) == [candidate.place.id])
        }
    }
    private func fixture(_ body: (URL) throws -> Void) throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory.appendingPathComponent("config.toml"))
    }
    private func place(_ index: Int, pinned: Bool = false) -> NavigationPlace {
        NavigationPlace(window: .init(bundleID: "test.app", title: "Window \(index)"),
            appName: "Test", regionName: "Window", region: nil, pinned: pinned,
            lastVisited: Date(timeIntervalSince1970: Double(1000 + index)))
    }
    private func load(_ url: URL) -> Controller {
        let controller = Controller(configurationURL: url)
        controller.loadConfigurationAtStartup() // No controller start, AX actions, or input taps.
        return controller
    }
    @Test func configPersistsAllPlacesAndLastVisitAcrossRestartAndPanelEdits() throws {
        try fixture { url in
            var config = AppConfiguration(); config.stacks = .init()
            config.hints.alphabet = "asdf"; config.apps.list = ["Example"]
            try config.toml().write(to: url, atomically: true, encoding: .utf8)
            let model = load(url)
            let saved = NavigationStacks(places: [place(0, pinned: true), place(1), place(2)])
            try model.persistStacks(saved); model.stacks = saved
            model.theme = .dracula
            let restarted = load(url)
            #expect(restarted.stacks.ordered == saved.ordered)
            #expect(restarted.stacks.last == saved.last)
            #expect(restarted.theme == .dracula && restarted.apps == config.apps.list)
            #expect(restarted.hintConfiguration.alphabet == "asdf")
            #expect(!FileManager.default.fileExists(atPath: url.deletingLastPathComponent().appendingPathComponent("stacks.json").path))
        }
    }
    @Test func stackSavesProtectExternallyEditedAndDeletedConfig() throws {
        try fixture { url in
            let model = load(url)
            let source = try String(contentsOf: url, encoding: .utf8) + "\n# External edit\n"
            try source.write(to: url, atomically: true, encoding: .utf8)
            #expect(throws: (any Error).self) { try model.persistStacks(NavigationStacks(places: [place(1)])) }
            #expect(try String(contentsOf: url, encoding: .utf8) == source)
            model.reloadConfiguration()
            try FileManager.default.removeItem(at: url)
            #expect(throws: (any Error).self) { try model.persistStacks(NavigationStacks()) }
            #expect(!FileManager.default.fileExists(atPath: url.path))
        }
    }
    @Test func removeAndUndoPersistPlacesAndRestoreTheirNumericOrder() throws {
        try fixture { url in
            let model = load(url)
            var history = NavigationStacks(places: [place(0, pinned: true), place(2), place(1)])
            var picker = StackPickerState(entries: history.ordered)
            let undo = (history, picker)
            try model.persistStacks(history)
            let pinID = history.ordered[0].id
            history.remove(pinID); picker.remove(pinID)
            try model.persistStacks(history)
            #expect(load(url).stacks.ordered == history.ordered)
            #expect(picker.codes == ["1", "2"])
            let recentID = history.ordered[0].id
            history.remove(recentID); picker.remove(recentID)
            try model.persistStacks(history)
            #expect(load(url).stacks.ordered == history.ordered)
            #expect(picker.codes == ["1"])
            history = undo.0; picker = undo.1
            try model.persistStacks(history)
            #expect(load(url).stacks.ordered == undo.0.ordered)
            #expect(picker.codes == ["1", "2", "3"])
        }
    }
    @Test func legacyPinsMigrateOnceAndAnEmptyTOMLDoesNotResurrectThem() throws {
        try fixture { url in
            struct Legacy: Encodable { let version = 1; let pins: [NavigationPlace] }
            let pin = place(0, pinned: true)
            let legacy = url.deletingLastPathComponent().appendingPathComponent("stacks.json")
            let bytes = try JSONEncoder().encode(Legacy(pins: [pin, place(1)]))
            try bytes.write(to: legacy)
            let model = load(url)
            #expect(model.stacks.ordered == [pin])
            #expect(try Data(contentsOf: legacy) == bytes)
            try model.persistStacks(NavigationStacks())
            #expect(load(url).stacks.places.isEmpty)
            #expect(try Data(contentsOf: legacy) == bytes)
        }
    }
    @Test func failedMigrationPreservesBothFilesAndCanRetryOnReload() throws {
        try fixture { url in
            let legacy = url.deletingLastPathComponent().appendingPathComponent("stacks.json")
            try Data("bad legacy data".utf8).write(to: legacy)
            let source = try AppConfiguration().toml()
            try source.write(to: url, atomically: true, encoding: .utf8)
            let model = load(url)
            #expect(model.stackSaveError != nil && !model.stacksConfigured)
            #expect(throws: (any Error).self) { try model.persistStacks(NavigationStacks(places: [place(1)])) }
            #expect(try String(contentsOf: url, encoding: .utf8) == source)
            #expect(try String(contentsOf: legacy, encoding: .utf8) == "bad legacy data")
            try Data("{\"version\":1,\"pins\":[]}".utf8).write(to: legacy)
            model.reloadConfiguration()
            #expect(model.stackSaveError == nil && model.stacksConfigured)
        }
    }
}
