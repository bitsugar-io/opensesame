import Foundation
import Testing
@testable import OpenSesameCore

@Test func tomlRoundTripsAllPreferencesAndEscapedAppNames() throws {
    var config = AppConfiguration()
    config.hints.size = 20; config.hints.menuBar = false
    config.hints.minimumLength = 3; config.hints.alphabet = "asdf"; config.hints.prefix = "xy"
    config.apps.mode = .only; config.apps.list = ["Ghostty", "An app with \"quotes\" and \\ slashes", "应用"]
    #expect(try AppConfiguration.parse(config.toml()) == config)
}
@Test func tomlDefaultsAndCommentsAreSupported() throws {
    let config = try AppConfiguration.parse("# Personal settings\n[hints]\nsize = 12 # smaller\n")
    #expect(config.hints.size == 12)
    #expect(config.hints.minimumLength == 2)
    #expect(config.apps.mode == .except)
}
@Test func tomlRejectsTyposInvalidSizesAndAmbiguousLetters() {
    for source in ["[hints]\nszie = 16", "[hints]\nsize = 9", "[hints]\nsize = 16.5", "[hints]\nalphabet = 'aa'", "[hints]\nminimum_length = 4", "[apps]\nmode = 'all'", "[apps]\nlist = ['']", "[wrong]\na = 1"] {
        #expect(throws: (any Error).self) { try AppConfiguration.parse(source) }
    }
}
@Test func configLocationUsesOnlyAbsoluteXDGOverrides() {
    let home = URL(fileURLWithPath: "/tmp/home")
    #expect(AppConfiguration.location(environment: [:], home: home).path == "/tmp/home/.config/opensesame/config.toml")
    #expect(AppConfiguration.location(environment: ["XDG_CONFIG_HOME": "/tmp/config"], home: home).path == "/tmp/config/opensesame/config.toml")
    #expect(AppConfiguration.location(environment: ["XDG_CONFIG_HOME": "relative"], home: home).path == "/tmp/home/.config/opensesame/config.toml")
}
