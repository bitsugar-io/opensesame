import Foundation

public enum TargetKind: String, Hashable {
    case control, tab, close, menu, window, desktop
    public var followsOpenedSurface: Bool { self != .tab && self != .close && self != .window }
    public var marker: String {
        switch self {
        case .control: return ""
        case .tab: return "↔"
        case .close: return "×"
        case .menu: return "›"
        case .window: return "▣"
        case .desktop: return ""
        }
    }
    public static func classify(role: String, subrole: String, parentRole: String, description: String) -> Self {
        let name = description.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if role == "AXTabGroup", parentRole == "AXTabGroup" { return .tab }
        if subrole != "AXCloseButton", ["AXTab", "AXTabButton"].contains(role) || (role == "AXRadioButton" && parentRole == "AXTabGroup") { return .tab }
        if subrole == "AXCloseButton" || ["close", "close tab", "close window", "close button", "close tab button"].contains(name) { return .close }
        if ["AXTab", "AXTabButton"].contains(role) || subrole == "AXTabButton" || (parentRole == "AXTabGroup" && ["AXRadioButton", "AXButton"].contains(role)) { return .tab }
        if ["AXMenuBarItem", "AXMenuItem", "AXPopUpButton", "AXMenuButton"].contains(role) { return .menu }
        return .control
    }
}

// Keep distinct actions, roles, owners, and named controls even at identical bounds.
// Repeated AX nodes with identical semantics and geometry receive only one hint.
public struct TargetIdentity: Hashable {
    public let pid: Int32
    public let role: String
    public let name: String
    public let action: String
    public let kind: TargetKind
    public let x: Double, y: Double, width: Double, height: Double
    public init(pid: Int32, role: String, name: String, action: String, kind: TargetKind,
                x: Double, y: Double, width: Double, height: Double) {
        self.pid = pid; self.role = role; self.name = name; self.action = action; self.kind = kind
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}
