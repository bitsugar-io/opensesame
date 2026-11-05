import Foundation

/// The blocking event callback uses only this bounded state machine, never UI or AX.
public struct KeyboardRouting {
    public struct Snapshot {
        public var generation: UUID
        public var shortcut: Shortcut
        public var enabled: Bool
        public var recording: Bool
        public var active: Bool
        public var pending: Bool
        public var labels: [String]
        public var keyCharacters: [Int: String]
        public var canPage: Bool
        public init(generation: UUID, shortcut: Shortcut, enabled: Bool, recording: Bool, active: Bool, pending: Bool, labels: [String], canPage: Bool = false, keyCharacters: [Int: String] = [:]) {
            self.generation = generation; self.shortcut = shortcut; self.enabled = enabled; self.recording = recording
            self.active = active; self.pending = pending; self.labels = labels; self.canPage = canPage; self.keyCharacters = keyCharacters
        }
    }
    public enum Decision: Equatable {
        case pass
        case consume
        case handle(consume: Bool, generation: UUID?)
        case cancelAndPass
    }
    private var snapshot: Snapshot?
    private var heartbeat: TimeInterval = 0
    private var prefix = ""
    private var disarmed = false
    public init() {}
    public mutating func update(_ snapshot: Snapshot, now: TimeInterval) {
        if self.snapshot?.generation != snapshot.generation { prefix = ""; disarmed = false }
        self.snapshot = snapshot; heartbeat = now
    }
    @discardableResult public mutating func disarm() -> Bool {
        let session = snapshot.map { $0.active || $0.pending } ?? false
        disarmed = true
        return session
    }
    public mutating func route(key: Int, modifiers: Set<String>, text: String, repeating: Bool, now: TimeInterval) -> Decision {
        guard let snapshot, snapshot.enabled, !snapshot.recording else { return .pass }
        // A blocked main thread must never leave the keyboard captive. Recovery
        // requires a fresh session; late heartbeats cannot rearm the old one.
        guard now - heartbeat <= 0.75 else {
            let wasCapturing = snapshot.active && !disarmed
            disarmed = true
            return wasCapturing ? .cancelAndPass : .pass
        }
        if key == 20, modifiers.isSuperset(of: ["command", "shift"]), !modifiers.contains("option") { return .pass }
        if key == snapshot.shortcut.keyCode, modifiers == Set(snapshot.shortcut.modifiers) {
            if snapshot.active || snapshot.pending { disarmed = true }
            return repeating ? .consume : .handle(consume: true, generation: nil)
        }
        guard !disarmed else { return .pass }
        guard snapshot.active else {
            if snapshot.pending { disarmed = true; return .handle(consume: false, generation: snapshot.generation) }
            return .pass
        }
        if key == 53 { disarmed = true; return .handle(consume: true, generation: snapshot.generation) }
        if key == 51 { if !prefix.isEmpty { prefix.removeLast() }; return .handle(consume: true, generation: snapshot.generation) }
        guard modifiers.isDisjoint(with: ["control", "option", "command"]) else {
            disarmed = true; return .handle(consume: false, generation: snapshot.generation)
        }
        if key == 48, snapshot.canPage { return .handle(consume: true, generation: snapshot.generation) }
        guard let character = Hints.inputCharacter(text.isEmpty ? (snapshot.keyCharacters[key] ?? "") : text) else {
            disarmed = true; return .handle(consume: false, generation: snapshot.generation)
        }
        let candidate = prefix + character
        if snapshot.labels.contains(where: { $0.hasPrefix(candidate) }) {
            prefix = candidate
            if snapshot.labels.contains(candidate) { disarmed = true }
        }
        return .handle(consume: true, generation: snapshot.generation)
    }
}
