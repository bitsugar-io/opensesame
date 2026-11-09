import AppKit
import Carbon
import SQLite3

/// Optional metadata only. No tab activation, network requests, history reads,
/// title-to-URL guessing, or permission prompts during discovery.
enum ChromeIconAdapter {
    struct Tab: Decodable { let title: String; let url: String }
    struct Window: Decodable { let bounds: [Double]; let tabs: [Tab] }
    static func permission(ask: Bool) -> OSStatus {
        guard NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.Chrome").isEmpty == false else { return OSStatus(procNotFound) }
        let target = NSAppleEventDescriptor(bundleIdentifier: "com.google.Chrome")
        return AEDeterminePermissionToAutomateTarget(target.aeDesc, AEEventClass(kAECoreSuite), AEEventID(kAEGetData), ask)
    }
    static func enrich(_ targets: [Target], window: CGRect) -> [Target] {
        let tabs = targets.filter { $0.kind == .tab && $0.metadata.role != "AXTabGroup" && $0.metadata.bundleID == "com.google.Chrome" }
        guard !tabs.isEmpty, permission(ask: false) == noErr,
              let data = snapshot(window: window),
              let windows = try? JSONDecoder().decode([Window].self, from: data) else { return targets }
        let mapping = urls(for: tabs.map(\.metadata.title), window: window, snapshots: windows)
        guard !mapping.isEmpty else { return targets }
        let cache = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Google/Chrome")
        let icons = cachedIcons(urls: Set(mapping.values), root: cache)
        return targets.map { target in
            var result = target
            if target.kind == .tab, target.metadata.role != "AXTabGroup", target.metadata.bundleID == "com.google.Chrome",
               let url = mapping[target.metadata.title], let icon = icons[url] { result.metadata.iconData = icon }
            return result
        }
    }
    static func urls(for titles: [String], window: CGRect, snapshots: [Window]) -> [String: String] {
        let matches = snapshots.filter { item in
            item.bounds.count == 4 && zip(item.bounds, [window.minX, window.minY, window.width, window.height]).allSatisfy { abs($0 - $1) <= 2 }
        }
        guard matches.count == 1 else { return [:] }
        let live = Dictionary(grouping: matches[0].tabs, by: \.title)
        let ax = Dictionary(grouping: titles, by: { $0 })
        var result: [String: String] = [:]
        for (title, sameName) in ax where sameName.count == 1 && !title.isEmpty {
            guard let candidates = live[title], candidates.count == 1, candidates[0].url.count <= 8192,
                  let url = URL(string: candidates[0].url), ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { continue }
            result[title] = candidates[0].url
        }
        return result
    }
    private static func snapshot(window: CGRect) -> Data? {
        // Fixed script; geometry travels as arguments, never executable source.
        // Only the matching non-incognito window is read. Titles/URLs stay in RAM.
        let script = #"""
        function run(argv) {
          const app = Application('com.google.Chrome');
          if (!app.running()) return '[]';
          const expected = argv.map(Number), result = [];
          for (const w of app.windows()) {
            if (w.mode() !== 'normal') continue;
            const b = w.bounds(), bounds = [b.x, b.y, b.width, b.height];
            if (!bounds.every((n, i) => Math.abs(n - expected[i]) <= 2)) continue;
            const tabs = w.tabs().slice(0, 256).map(t => ({ title: t.title(), url: t.url() }));
            result.push({bounds: bounds, tabs: tabs});
          }
          const text = JSON.stringify(result);
          return text.length <= 262144 ? text : '[]';
        }
        """#
        let process = Process(), pipe = Pipe(), finished = DispatchSemaphore(value: 0)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-l", "JavaScript", "-e", script] + [window.minX, window.minY, window.width, window.height].map { String(Double($0)) }
        process.standardOutput = pipe; process.standardError = FileHandle.nullDevice
        let buffer = CommandBuffer()
        process.terminationHandler = { _ in finished.signal() }
        do { try process.run() } catch { return nil }
        let readDone = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .utility).async {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            buffer.store(data); readDone.signal()
        }
        if finished.wait(timeout: .now() + 1) == .timedOut {
            process.terminate()
            if finished.wait(timeout: .now() + 0.1) == .timedOut { kill(process.processIdentifier, SIGKILL) }
            return nil
        }
        guard process.terminationStatus == 0, readDone.wait(timeout: .now() + 0.1) == .success else { return nil }
        let data = buffer.value()
        return data.count <= 1_048_576 ? data : nil
    }
    private final class CommandBuffer: @unchecked Sendable {
        private let lock = NSLock()
        private var data = Data()
        func store(_ value: Data) { lock.lock(); defer { lock.unlock() }; data = value }
        func value() -> Data { lock.lock(); defer { lock.unlock() }; return data }
    }
    private final class QueryBudget {
        let deadline: Date
        init(_ deadline: Date) { self.deadline = deadline }
    }
    static func cachedIcons(urls: Set<String>, root: URL) -> [String: Data] {
        let fm = FileManager.default
        let profiles = ((try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []).filter {
            $0.lastPathComponent == "Default" || $0.lastPathComponent.range(of: #"^Profile \d+$"#, options: .regularExpression) != nil
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }.prefix(16)
        let deadline = Date().addingTimeInterval(0.5)
        var result: [String: Data] = [:]
        for profile in profiles where Date() < deadline {
            let found = readCache(profile.appendingPathComponent("Favicons"), urls: urls, deadline: deadline)
            // If profiles disagree, a website icon is still identity metadata;
            // use the first cached representation deterministically.
            result.merge(found) { existing, _ in existing }
            if result.count == urls.count { break }
        }
        return result
    }
    static func readCache(_ source: URL, urls: Set<String>, deadline: Date) -> [String: Data] {
        let fm = FileManager.default
        guard let before = try? source.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]),
              before.isRegularFile == true, let size = before.fileSize, size <= 64 * 1024 * 1024 else { return [:] }
        // Chrome may hold an exclusive database lock. Copy only its last
        // checkpointed main file, verify it did not change during copying, then
        // read that private snapshot. Never open Chrome's database for writing.
        let directory = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let copy = directory.appendingPathComponent("Favicons")
        defer { try? fm.removeItem(at: directory) }
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            try fm.copyItem(at: source, to: copy)
            let after = try source.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            guard before.contentModificationDate == after.contentModificationDate, before.fileSize == after.fileSize else { return [:] }
        } catch { return [:] }
        var database: OpaquePointer?
        guard sqlite3_open_v2(copy.path, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            if let database { sqlite3_close(database) }; return [:]
        }
        let budget = QueryBudget(deadline)
        sqlite3_progress_handler(database, 1000, { context in
            guard let context else { return 1 }
            return Date() >= Unmanaged<QueryBudget>.fromOpaque(context).takeUnretainedValue().deadline ? 1 : 0
        }, Unmanaged.passUnretained(budget).toOpaque())
        defer { sqlite3_progress_handler(database, 0, nil, nil); sqlite3_close(database); withExtendedLifetime(budget) {} }
        var statement: OpaquePointer?
        let query = """
        SELECT b.image_data FROM icon_mapping m JOIN favicon_bitmaps b ON b.icon_id = m.icon_id
        WHERE m.page_url = ? AND b.width BETWEEN 1 AND 512 AND b.height BETWEEN 1 AND 512
        AND length(b.image_data) BETWEEN 1 AND 262144 ORDER BY abs(b.width - 32), b.last_updated DESC LIMIT 1
        """
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_finalize(statement) }
        var result: [String: Data] = [:]
        for url in urls.sorted().prefix(256) where Date() < deadline {
            sqlite3_reset(statement); sqlite3_clear_bindings(statement)
            _ = url.withCString { sqlite3_bind_text(statement, 1, $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
            guard sqlite3_step(statement) == SQLITE_ROW, let bytes = sqlite3_column_blob(statement, 0) else { continue }
            result[url] = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0)))
        }
        return result
    }
}
