import Foundation
import OpenSesameCore

/// Legacy favorites are read only for migration. ConfigurationStore owns all
/// new stack writes in config.toml; this file is never modified during migration.
final class StackStore {
    private struct Document: Decodable { var version: Int; var pins: [NavigationPlace] }
    let url: URL
    init(url: URL) { self.url = url }
    func load() throws -> [NavigationPlace] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        let document = try JSONDecoder().decode(Document.self, from: data)
        guard document.version == 1 else { throw ConfigurationError.invalid("Unknown stacks file version.") }
        let pins = document.pins.filter(\.pinned)
        guard pins.count <= NavigationStacks.capacity, Set(pins.map(\.id)).count == pins.count else {
            throw ConfigurationError.invalid("Stacks support five unique pins. The existing file was left unchanged.")
        }
        return pins
    }
}
