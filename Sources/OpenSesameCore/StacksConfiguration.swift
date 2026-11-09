import Foundation

/// The five saved places are ordinary TOML data, not a second preferences file.
public struct StacksConfiguration: Equatable, Decodable {
    public var places: [NavigationPlace]
    public init(places: [NavigationPlace] = []) { self.places = places }
    enum CodingKeys: String, CodingKey { case version, places }
    public init(from decoder: Decoder) throws {
        try checkKeys(decoder, allowed: ["version", "places"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard (try c.decodeIfPresent(Int.self, forKey: .version) ?? 1) == 1 else { throw ConfigurationError.invalid("Unknown stacks version.") }
        places = try c.decodeIfPresent([SavedPlace].self, forKey: .places)?.map(\.place) ?? []
        guard places.count <= NavigationStacks.capacity, Set(places.map(\.id)).count == places.count else {
            throw ConfigurationError.invalid("stacks.places must contain at most five unique places.")
        }
    }
    private struct SavedPlace: Decodable {
        let place: NavigationPlace
        enum CodingKeys: String, CodingKey {
            case id, window, anchors, bounds, pinned
            case appName = "app_name", regionName = "region_name", lastVisited = "last_visited"
        }
        init(from decoder: Decoder) throws {
            try checkKeys(decoder, allowed: ["id", "window", "anchors", "bounds", "pinned", "app_name", "region_name", "last_visited"])
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let idText = try c.decode(String.self, forKey: .id)
            guard let id = UUID(uuidString: idText) else { throw ConfigurationError.invalid("A stack id must be a UUID.") }
            let window = try c.decode(StackWindow.self, forKey: .window)
            let anchors = try c.decodeIfPresent([StackAnchor].self, forKey: .anchors)
            let bounds = try c.decodeIfPresent(StackRegionBounds.self, forKey: .bounds)
            guard bounds?.isValid != false, bounds == nil || anchors != nil else { throw ConfigurationError.invalid("Invalid saved stack region bounds.") }
            let date = try c.decode(Double.self, forKey: .lastVisited)
            guard !window.bundleID.isEmpty, date.isFinite, (anchors?.count ?? 0) <= 128,
                  anchors?.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) != false else { throw ConfigurationError.invalid("Invalid saved stack identity or anchors.") }
            place = NavigationPlace(id: id, window: window, appName: try c.decode(String.self, forKey: .appName),
                regionName: try c.decode(String.self, forKey: .regionName), region: anchors.map { StackRegion(anchors: $0, bounds: bounds) },
                pinned: try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false, lastVisited: Date(timeIntervalSince1970: date))
        }
    }
    public func toml() throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.withoutEscapingSlashes]
        func q(_ value: String) throws -> String { String(decoding: try encoder.encode(value), as: UTF8.self) }
        var result = "[stacks]\nversion = 1\n"
        if places.isEmpty { return result + "places = []\n" }
        for place in places {
            result += """

            [[stacks.places]]
            id = \(try q(place.id.uuidString))
            app_name = \(try q(place.appName))
            region_name = \(try q(place.regionName))
            pinned = \(place.pinned)
            last_visited = \(place.lastVisited.timeIntervalSince1970)
            window = { bundleID = \(try q(place.window.bundleID)), title = \(try q(place.window.title)), identifier = \(try q(place.window.identifier)) }

            """
            if let region = place.region {
                if let b = region.bounds { result += "bounds = { x = \(b.x), y = \(b.y), width = \(b.width), height = \(b.height) }\n" }
                let anchors = try region.anchors.map {
                    "{ role = \(try q($0.role)), identifier = \(try q($0.identifier)), name = \(try q($0.name)), x = \($0.x), y = \($0.y) }"
                }
                result += "anchors = [\n" + anchors.map { "  " + $0 + "," }.joined(separator: "\n") + "\n]\n"
            }
        }
        return result
    }
}
