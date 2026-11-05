import Foundation

public struct HintLifecycle {
    public private(set) var generation = UUID()
    public private(set) var followupID = UUID()
    public private(set) var followingAction = false
    public init() {}

    public mutating func cancel(preservingFollowup: Bool = false) {
        generation = UUID()
        if !preservingFollowup {
            followingAction = false
            followupID = UUID()
        }
    }
    public mutating func beginFollowup() -> UUID {
        followupID = UUID()
        followingAction = true
        return followupID
    }
    public mutating func finishFollowup(_ ticket: UUID) {
        guard followupID == ticket else { return }
        followingAction = false
        followupID = UUID()
    }
    public func accepts(generation ticket: UUID, followup: UUID? = nil) -> Bool {
        guard generation == ticket else { return false }
        return followup.map { followingAction && followupID == $0 } ?? true
    }
}
