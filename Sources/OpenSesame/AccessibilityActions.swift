import ApplicationServices
import OpenSesameCore

enum AccessibilityActions {
    struct Plan { let action: String; let isDisclosure: Bool }
    static func canSet(_ element: AXUIElement, _ key: String) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, key as CFString, &settable) == .success && settable.boolValue
    }
    static func plan(_ element: AXUIElement, role: String, kind: TargetKind, advertised: [String],
                     read: (AXUIElement, String) -> CFTypeRef? = attribute,
                     writable: (AXUIElement, String) -> Bool = canSet) -> Plan? {
        var hasDisclosure = false, key: String?
        if kind == .desktop || AccessibilityActionPolicy.mayDisclose(role: role) {
            for candidate in AccessibilityActionPolicy.disclosureAttributes where read(element, candidate) is NSNumber {
                hasDisclosure = true
                if writable(element, candidate) { key = candidate; break }
            }
        }
        guard let action = AccessibilityActionPolicy.primary(role: role, kind: kind, advertised: advertised, writableDisclosure: key) else { return nil }
        return Plan(action: action, isDisclosure: hasDisclosure || role == "AXDisclosureTriangle")
    }
    static func perform(_ target: Target,
                        read: (AXUIElement, String) -> CFTypeRef? = attribute,
                        writable: (AXUIElement, String) -> Bool = canSet,
                        write: (AXUIElement, String, CFTypeRef) -> AXError = { AXUIElementSetAttributeValue($0, $1 as CFString, $2) },
                        press: (AXUIElement, String) -> AXError = { AXUIElementPerformAction($0, $1 as CFString) }) -> AXError {
        guard target.action.hasPrefix(AccessibilityActionPolicy.togglePrefix) else { return press(target.element, target.action) }
        let key = String(target.action.dropFirst(AccessibilityActionPolicy.togglePrefix.count))
        guard AccessibilityActionPolicy.disclosureAttributes.contains(key),
              let expanded = read(target.element, key) as? NSNumber, writable(target.element, key) else { return .attributeUnsupported }
        return write(target.element, key, expanded.boolValue ? kCFBooleanFalse : kCFBooleanTrue)
    }
}
