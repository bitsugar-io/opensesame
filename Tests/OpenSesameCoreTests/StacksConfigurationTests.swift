import Foundation
import Testing
@testable import OpenSesameCore

private func savedPlace(pinned: Bool = false) -> NavigationPlace {
    NavigationPlace(window: .init(bundleID: "test.app", title: "Quotes \" / \\ \n 日本語", identifier: "window-1"),
        appName: "Test", regionName: "Playback", region: .init(anchors: [
            .init(role: "AXButton", identifier: "play", name: "Play", x: 0.5, y: 0.9)
        ]), pinned: pinned, lastVisited: Date(timeIntervalSince1970: 1_800_000_000.25))
}

@Test func stacksTOMLRoundTripsPinsRecentsRootsAndOtherPreferences() throws {
    var config = AppConfiguration()
    config.theme = .gruvbox; config.hints.alphabet = "asdf"; config.apps.list = ["Example"]
    var recent = savedPlace(); recent.region = nil
    recent.lastVisited = recent.lastVisited.addingTimeInterval(10)
    config.stacks = .init(places: [savedPlace(pinned: true), recent])
    let restored = try AppConfiguration.parse(config.toml())
    #expect(restored == config)
    let stacks = NavigationStacks(places: try #require(restored.stacks).places)
    #expect(stacks.ordered == config.stacks?.places)
    #expect(stacks.last == recent)
    #expect(try AppConfiguration.parse("[stacks]\nversion = 1\nplaces = []").stacks == StacksConfiguration())
    #expect(try AppConfiguration.parse("").stacks == nil)
}

@Test func stacksTOMLRejectsInvalidIdentitiesCapacityAndAnchors() throws {
    let place = savedPlace()
    let source = try StacksConfiguration(places: [place]).toml()
    for invalid in [
        source.replacingOccurrences(of: "version = 1", with: "version = 2"),
        source.replacingOccurrences(of: "version = 1", with: "versoin = 1"),
        source.replacingOccurrences(of: place.id.uuidString, with: "not-a-uuid"),
        source.replacingOccurrences(of: "test.app", with: ""),
        source.replacingOccurrences(of: "last_visited = 1800000000.25", with: "last_visited = nan"),
        source.replacingOccurrences(of: "x = 0.5", with: "x = inf"),
        source.replacingOccurrences(of: "x = 0.5", with: "unknown = 0.5"),
        source.replacingOccurrences(of: "app_name", with: "app_nmae"),
        source.replacingOccurrences(of: "bundleID", with: "bundleId"),
        try StacksConfiguration(places: [place, place]).toml(),
        try StacksConfiguration(places: (0..<6).map { _ in savedPlace(pinned: true) }).toml()
    ] {
        #expect(throws: (any Error).self) { try AppConfiguration.parse(invalid) }
    }
    let anchor = "{ role = 'AXButton', name = 'Play', x = 0.5, y = 0.9 }"
    let tooMany = String(source.prefix(upTo: try #require(source.range(of: "anchors =")).lowerBound))
        + "anchors = [" + Array(repeating: anchor, count: 129).joined(separator: ",") + "]"
    #expect(throws: (any Error).self) { try AppConfiguration.parse(String(tooMany)) }
}

@Test func savedRegionBoundsRoundTripAndRejectUnknownOrInvalidFields() throws {
    var place = savedPlace()
    let anchors = try #require(place.region).anchors
    place.region = StackRegion(anchors: anchors, bounds: .init(x: 0.2, y: 0.7, width: 0.8, height: 0.3))
    let expected = StacksConfiguration(places: [place])
    let source = try expected.toml()
    #expect(try AppConfiguration.parse(source).stacks == expected)
    for invalid in [
        source.replacingOccurrences(of: "width = 0.8", with: "width = -0.8"),
        source.replacingOccurrences(of: "width = 0.8", with: "width = 1.0"),
        source.replacingOccurrences(of: "height = 0.3", with: "height = nan"),
        source.replacingOccurrences(of: "height = 0.3", with: "height = 0.3, typo = 1"),
        String(source.prefix(upTo: try #require(source.range(of: "anchors =")).lowerBound))
    ] {
        #expect(throws: (any Error).self) { try AppConfiguration.parse(invalid) }
    }
}
