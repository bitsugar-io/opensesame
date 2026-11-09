import Foundation
import SQLite3
import Testing
import OpenSesameCore
@testable import OpenSesame

@Test func iconMetadataRejectsAmbiguousTabsWindowsAndNonWebURLs() {
    let frame = CGRect(x: 10, y: 20, width: 800, height: 600)
    let window = ChromeIconAdapter.Window(bounds: [10, 20, 800, 600], tabs: [
        .init(title: "One", url: "https://example.test/one"),
        .init(title: "Duplicate", url: "https://example.test/a"),
        .init(title: "Duplicate", url: "https://example.test/b"),
        .init(title: "Local", url: "file:///private/document")])
    let titles = ["One", "Duplicate", "Local", "Missing"]
    #expect(ChromeIconAdapter.urls(for: titles, window: frame, snapshots: [window]) == ["One": "https://example.test/one"])
    #expect(ChromeIconAdapter.urls(for: ["One", "One"], window: frame, snapshots: [window]).isEmpty)
    #expect(ChromeIconAdapter.urls(for: titles, window: frame, snapshots: [window, window]).isEmpty)
    #expect(ChromeIconAdapter.urls(for: titles, window: frame.offsetBy(dx: 20, dy: 0), snapshots: [window]).isEmpty)
}

@Test func faviconCacheUsesExactBoundURLsAndNeverModifiesTheSource() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("Favicons")
    var database: OpaquePointer?
    #expect(sqlite3_open(url.path, &database) == SQLITE_OK)
    let sql = """
    CREATE TABLE icon_mapping(page_url TEXT, icon_id INTEGER);
    CREATE TABLE favicon_bitmaps(icon_id INTEGER, width INTEGER, height INTEGER, image_data BLOB, last_updated INTEGER);
    INSERT INTO icon_mapping VALUES('https://example.test/a', 1);
    INSERT INTO favicon_bitmaps VALUES(1, 32, 32, X'010203', 0);
    INSERT INTO icon_mapping VALUES('https://example.test/huge', 2);
    INSERT INTO favicon_bitmaps VALUES(2, 4096, 4096, X'04', 0);
    """
    #expect(sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK)
    sqlite3_close(database)
    let before = try Data(contentsOf: url)
    let found = ChromeIconAdapter.readCache(url, urls: ["https://example.test/a", "https://example.test/b", "https://example.test/huge", "' OR 1=1 --"], deadline: .distantFuture)
    #expect(found == ["https://example.test/a": Data([1, 2, 3])])
    #expect(try Data(contentsOf: url) == before)
    #expect(ChromeIconAdapter.readCache(url, urls: ["https://example.test/a"], deadline: .distantPast).isEmpty)
}
