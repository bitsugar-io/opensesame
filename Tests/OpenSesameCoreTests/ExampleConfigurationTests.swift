import Foundation
import Testing
@testable import OpenSesameCore

@Test func bundledExampleConfiguration() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let source = try String(contentsOf: root.appendingPathComponent("config.example.toml"), encoding: .utf8)
    let configuration = try AppConfiguration.parse(source)
    var defaults = AppConfiguration()
    defaults.stacks = StacksConfiguration() // New configurations start with no saved places.
    #expect(configuration == defaults)
}
