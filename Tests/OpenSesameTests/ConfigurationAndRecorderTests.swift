import AppKit
import Foundation
import Testing
import OpenSesameCore
@testable import OpenSesame

@MainActor
struct ConfigurationAndRecorderTests {
    private func fixture(_ body: (Controller, URL) throws -> Void) throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("config.toml")
        try AppConfiguration().toml().write(to: url, atomically: true, encoding: .utf8)
        let model = Controller(configurationURL: url)
        model.loadConfigurationAtStartup() // Does not start controller, AX, or input tap.
        try body(model, url)
    }
    private func key(_ code: UInt16, flags: NSEvent.ModifierFlags = [], text: String = "") throws -> NSEvent {
        try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
            windowNumber: 0, context: nil, characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code))
    }
    @Test func themeAndAppearanceSelectionsSaveTogetherWithCustomVariants() throws {
        try fixture { model, url in
            model.theme = .custom; model.appearanceMode = .light
            var custom = model.customTheme; custom.light.control = "#AA1144"; model.customTheme = custom
            let disk = try AppConfiguration.parse(String(contentsOf: url, encoding: .utf8))
            #expect(disk.theme == .custom && disk.appearance == .light)
            #expect(disk.custom.light.control == "#AA1144")
            #expect(disk.custom.dark == CustomTheme().dark)
        }
    }
    @Test func failedPanelSaveProtectsExternalEditsAndRestoresLoadedState() throws {
        try fixture { model, url in
            let previous = model.currentConfiguration()
            var external = previous; external.theme = .gruvbox
            let source = try external.toml()
            try source.write(to: url, atomically: true, encoding: .utf8)
            model.theme = .dracula
            #expect(!model.configurationValid)
            #expect(model.currentConfiguration() == previous)
            #expect(try String(contentsOf: url, encoding: .utf8) == source)
            model.reloadConfiguration()
            #expect(model.configurationValid && model.theme == .gruvbox)
        }
    }
    @Test func invalidReloadKeepsLastSettingsWithoutOverwritingFile() throws {
        try fixture { model, url in
            let previous = model.currentConfiguration()
            try "[hints]\nsize = 100".write(to: url, atomically: true, encoding: .utf8)
            model.reloadConfiguration()
            #expect(!model.configurationValid)
            #expect(model.currentConfiguration() == previous)
            #expect(try String(contentsOf: url, encoding: .utf8) == "[hints]\nsize = 100")
        }
    }
    @Test func shortcutRecorderSavesCombinationAndEscapeKeepsOldBinding() throws {
        try fixture { model, url in
            let button = RecorderButton(model: model)
            button.performClick(nil)
            #expect(model.recordingShortcut)
            #expect(button.accept(try key(40, flags: [.command, .option], text: "k")) == nil)
            #expect(!model.recordingShortcut)
            #expect(model.shortcut == Shortcut(keyCode: 40, modifiers: ["option", "command"], key: "K"))
            #expect(try AppConfiguration.parse(String(contentsOf: url, encoding: .utf8)).shortcut == model.shortcut)
            button.performClick(nil)
            _ = button.accept(try key(53))
            #expect(!model.recordingShortcut && model.shortcut.keyCode == 40)
        }
    }
    @Test func stacksRecorderSavesItsOwnBindingAndRejectsTheHintsBinding() throws {
        try fixture { model, url in
            let button = RecorderButton(model: model, purpose: .stacks)
            button.performClick(nil)
            _ = button.accept(try key(49, flags: [.control, .shift], text: " "))
            #expect(model.recordingShortcut && model.stacksShortcut == .stacks)
            #expect(model.configurationValid)
            _ = button.accept(try key(40, flags: [.option, .command], text: "k"))
            let disk = try AppConfiguration.parse(String(contentsOf: url, encoding: .utf8))
            #expect(disk.stacksShortcut.keyCode == 40 && disk.shortcut == Shortcut())
            #expect(!model.recordingShortcut)
            model.reloadConfiguration()
            #expect(model.stacksShortcut == disk.stacksShortcut)
        }
    }
    @Test func saveStackRecorderPersistsAndRejectsOtherBindings() throws {
        try fixture { model, url in
            let button = RecorderButton(model: model, purpose: .saveStack)
            button.performClick(nil)
            _ = button.accept(try key(49, flags: [.control, .option], text: " "))
            #expect(model.recordingShortcut && model.saveStackShortcut == .saveStack)
            _ = button.accept(try key(1, flags: [.option, .command], text: "s"))
            let disk = try AppConfiguration.parse(String(contentsOf: url, encoding: .utf8))
            #expect(disk.saveStackShortcut == model.saveStackShortcut)
            #expect(disk.saveStackShortcut.keyCode == 1 && !model.recordingShortcut)
            model.reloadConfiguration()
            #expect(model.saveStackShortcut == disk.saveStackShortcut)
        }
    }
    @Test func recorderRejectsUnmodifiedLettersAndStopsAfterConfigurationError() throws {
        try fixture { model, _ in
            let button = RecorderButton(model: model)
            button.performClick(nil)
            _ = button.accept(try key(0, text: "a"))
            #expect(model.recordingShortcut && model.shortcut == Shortcut())
            model.configurationValid = false
            _ = button.accept(try key(40, flags: [.command], text: "k"))
            #expect(!model.recordingShortcut && model.shortcut == Shortcut())
            button.performClick(nil)
            #expect(!model.recordingShortcut)
        }
    }
}

@MainActor
struct ReadableAlphabetMigrationTests {
    @Test(arguments: [HintConfiguration.legacyAlphabet, HintConfiguration.previousDefaultAlphabet])
    func startupUpgradesTheOldAlphabetAndKeepsCustomLetters(oldAlphabet: String) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("config.toml")
        var config = AppConfiguration()
        config.stacks = StacksConfiguration()
        config.hints.alphabet = oldAlphabet
        config.hints.minimumLength = 3; config.hints.prefix = "k"
        try config.toml().write(to: url, atomically: true, encoding: .utf8)
        let model = Controller(configurationURL: url)
        model.loadConfigurationAtStartup()
        let saved = try AppConfiguration.parse(String(contentsOf: url, encoding: .utf8))
        #expect(saved.hints.alphabet == HintConfiguration.defaultAlphabet)
        #expect(saved.hints.minimumLength == 3 && saved.hints.prefix == "k")
        config.hints.alphabet = "avy"
        let custom = try config.toml()
        try custom.write(to: url, atomically: true, encoding: .utf8)
        model.loadConfigurationAtStartup()
        #expect(model.hintConfiguration.alphabet == "avy")
        #expect(try String(contentsOf: url, encoding: .utf8) == custom)
    }
}
