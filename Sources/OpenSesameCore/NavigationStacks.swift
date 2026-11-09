import Foundation

/// Saved destinations contain identity and structural anchors, never AX objects,
/// desktop coordinates, hint codes, or an action to replay.
public struct StackWindow: Codable, Equatable {
    public var bundleID: String
    public var title: String
    public var identifier: String
    public init(bundleID: String, title: String, identifier: String = "") {
        self.bundleID = bundleID; self.title = title; self.identifier = identifier
    }
    enum CodingKeys: String, CodingKey { case bundleID, title, identifier }
    public init(from decoder: Decoder) throws {
        try checkKeys(decoder, allowed: ["bundleID", "title", "identifier"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bundleID = try c.decode(String.self, forKey: .bundleID)
        title = try c.decode(String.self, forKey: .title)
        identifier = try c.decodeIfPresent(String.self, forKey: .identifier) ?? ""
    }
    public func uniqueMatch(in windows: [StackWindow]) -> Int? {
        let matches = windows.indices.filter { index in
            let window = windows[index]
            guard window.bundleID == bundleID else { return false }
            if !identifier.isEmpty { return window.identifier == identifier }
            return !title.isEmpty && window.title == title
        }
        return matches.count == 1 ? matches[0] : nil
    }
}

public struct StackAnchor: Codable, Equatable {
    public let role: String
    public let identifier: String
    public let name: String
    public let x: Double
    public let y: Double
    public init(role: String, identifier: String = "", name: String, x: Double, y: Double) {
        self.role = role; self.identifier = identifier; self.name = name; self.x = x; self.y = y
    }
    enum CodingKeys: String, CodingKey { case role, identifier, name, x, y }
    public init(from decoder: Decoder) throws {
        try checkKeys(decoder, allowed: ["role", "identifier", "name", "x", "y"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        role = try c.decode(String.self, forKey: .role)
        identifier = try c.decodeIfPresent(String.self, forKey: .identifier) ?? ""
        name = try c.decode(String.self, forKey: .name)
        x = try c.decode(Double.self, forKey: .x); y = try c.decode(Double.self, forKey: .y)
    }
    public var hasIdentity: Bool { !identifier.isEmpty || !name.isEmpty }
    func matches(_ other: Self) -> Bool {
        guard role == other.role, abs(x - other.x) <= 0.18, abs(y - other.y) <= 0.18 else { return false }
        return identifier.isEmpty ? (!name.isEmpty && name == other.name) : identifier == other.identifier
    }
}

/// Window-relative pane identity survives movement, resizing and content changes.
public struct StackRegionBounds: Codable, Equatable {
    public let x: Double, y: Double, width: Double, height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
    enum CodingKeys: String, CodingKey { case x, y, width, height }
    public init(from decoder: Decoder) throws {
        try checkKeys(decoder, allowed: ["x", "y", "width", "height"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        x = try c.decode(Double.self, forKey: .x); y = try c.decode(Double.self, forKey: .y)
        width = try c.decode(Double.self, forKey: .width); height = try c.decode(Double.self, forKey: .height)
    }
    public var isValid: Bool {
        [x, y, width, height].allSatisfy(\.isFinite) && x >= -0.01 && y >= -0.01
            && width > 0 && height > 0 && x + width <= 1.01 && y + height <= 1.01
    }
    func matches(_ other: Self) -> Bool {
        zip([x, y, width, height], [other.x, other.y, other.width, other.height]).allSatisfy { abs($0 - $1) <= 0.025 }
    }
}

public struct StackRegion: Codable, Equatable {
    public let anchors: [StackAnchor]
    public let bounds: StackRegionBounds?
    public init(anchors: [StackAnchor], bounds: StackRegionBounds? = nil) {
        self.anchors = Array(anchors.filter(\.hasIdentity).prefix(128)); self.bounds = bounds
    }
    /// Save identity is separate from recall confidence. Legacy saves lack
    /// bounds; require three stable controls and the same region name before
    /// treating changed content as an update to that destination.
    public func sameSavedRegion(as other: Self, sameName: Bool) -> Bool {
        if let bounds, let otherBounds = other.bounds { return bounds.matches(otherBounds) }
        if similarity(to: other) != nil { return true }
        guard sameName else { return false }
        var available = Set(other.anchors.indices), matched = 0
        for anchor in anchors {
            if let index = available.first(where: {
                let candidate = other.anchors[$0]
                return anchor.matches(candidate) && abs(anchor.x - candidate.x) <= 0.03 && abs(anchor.y - candidate.y) <= 0.03
            }) { available.remove(index); matched += 1 }
        }
        return matched >= 3
    }

    /// Both coverage ratios matter: a whole window containing these same few
    /// controls is not the saved region. Ambiguous matches are rejected by callers.
    public func similarity(to other: Self) -> Double? {
        guard !anchors.isEmpty, !other.anchors.isEmpty else { return nil }
        var available = Set(other.anchors.indices)
        var matched = 0
        for anchor in anchors {
            let candidates = available.filter { anchor.matches(other.anchors[$0]) }.sorted {
                hypot(anchor.x - other.anchors[$0].x, anchor.y - other.anchors[$0].y)
                    < hypot(anchor.x - other.anchors[$1].x, anchor.y - other.anchors[$1].y)
            }
            if let index = candidates.first { available.remove(index); matched += 1 }
        }
        let score = Double(matched) / Double(max(anchors.count, other.anchors.count))
        guard matched >= min(2, anchors.count), score >= 0.6 else { return nil }
        return score
    }

    /// A loose coverage threshold tolerates changing content, but must never
    /// choose between two similarly plausible destinations by array order.
    public func uniqueMatch(in regions: [Self]) -> Int? {
        let matches = regions.indices.compactMap { index in
            similarity(to: regions[index]).map { (index: index, score: $0) }
        }.sorted { $0.score > $1.score }
        guard let best = matches.first,
              matches.count == 1 || best.score - matches[1].score > 0.1 else { return nil }
        return best.index
    }
}

public struct NavigationPlace: Codable, Equatable, Identifiable {
    public var id: UUID
    public var window: StackWindow
    public var appName: String
    public var regionName: String
    public var region: StackRegion? // nil means the window's root choices
    public var pinned: Bool
    public var lastVisited: Date
    public init(id: UUID = UUID(), window: StackWindow, appName: String, regionName: String,
                region: StackRegion?, pinned: Bool = false, lastVisited: Date = Date()) {
        self.id = id; self.window = window; self.appName = appName; self.regionName = regionName
        self.region = region; self.pinned = pinned; self.lastVisited = lastVisited
    }
}

public struct NavigationStacks {
    public static let capacity = 5
    public private(set) var places: [NavigationPlace]
    private var trail: [UUID] = []
    public init(pins: [NavigationPlace] = []) { self.init(places: pins.filter(\.pinned)) }
    public init(places: [NavigationPlace]) {
        var seen = Set<UUID>()
        self.places = Array(places.filter { seen.insert($0.id).inserted }.prefix(Self.capacity))
    }
    public var ordered: [NavigationPlace] { places }
    public var pins: [NavigationPlace] { places.filter(\.pinned) }
    public var last: NavigationPlace? {
        trail.last.flatMap { id in places.first { $0.id == id } } ?? places.max { $0.lastVisited < $1.lastVisited }
    }
    /// Only an explicit Save action may insert or update a destination. Never
    /// evict another saved place, and keep its slot when updating it.
    @discardableResult
    public mutating func save(_ place: NavigationPlace, replacing duplicates: [UUID] = []) throws -> UUID {
        var saved = place; saved.pinned = true
        // Only explicit Save consolidates confirmed matches. Preserve the
        // earliest slot and never remove an unrelated destination on load.
        let duplicateSet = Set(duplicates + [place.id])
        if let first = places.first(where: { duplicateSet.contains($0.id) }) {
            saved.id = first.id
            for id in duplicateSet where id != first.id { remove(id) }
        }
        if let index = places.firstIndex(where: { $0.id == saved.id }) { places[index] = saved }
        else {
            guard places.count < Self.capacity else {
                throw ConfigurationError.invalid("All five stacks are filled. Remove a place before saving another.")
            }
            places.append(saved)
        }
        visit(saved.id, at: place.lastVisited)
        return saved.id
    }
    /// Recall can update existing history, but cannot create a stack or change
    /// its saved region. Ordinary hint use never calls this.
    public mutating func visit(_ id: UUID, at date: Date = Date()) {
        guard let index = places.firstIndex(where: { $0.id == id }) else { return }
        places[index].lastVisited = date
        if trail.last != id { trail.append(id) }
        if trail.count > 64 { trail.removeFirst(trail.count - 64) }
    }
    public mutating func previous() -> NavigationPlace? {
        guard trail.count > 1 else { return nil }
        trail.removeLast()
        return last
    }
    public mutating func remove(_ id: UUID) {
        places.removeAll { $0.id == id }
        trail.removeAll { $0 == id }
    }
}

/// Numeric shortcuts always match the current top-to-bottom order.
public struct StackPickerState {
    public var entries: [NavigationPlace]
    public private(set) var codes: [String]
    public var prefix = ""
    public var selected: UUID?
    public var notice: String?
    public init(entries: [NavigationPlace]) {
        self.entries = Array(entries.prefix(NavigationStacks.capacity))
        codes = self.entries.indices.map { String($0 + 1) }
        selected = self.entries.first?.id
    }
    public var matchingIndices: [Int] { entries.indices.filter { codes[$0].hasPrefix(prefix) } }
    public mutating func move(_ delta: Int) {
        let matches = matchingIndices
        guard !matches.isEmpty else { return }
        let current = matches.firstIndex { entries[$0].id == selected } ?? 0
        selected = entries[matches[(current + delta % matches.count + matches.count) % matches.count]].id
    }
    public mutating func remove(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries.remove(at: index); codes = entries.indices.map { String($0 + 1) }
        prefix = ""
        if selected == id { selected = entries.isEmpty ? nil : entries[min(index, entries.count - 1)].id }
    }
}
