import ApplicationServices

enum AccessibilityPreparation {
    /// Some native renderers publish their child tree only after an assistive
    /// client requests it. This changes the target app's AX mode, never TCC or
    /// system VoiceOver settings, and is independent of its bundle identifier.
    static func enableTree(_ app: AXUIElement,
                           read: (AXUIElement, String) -> CFTypeRef? = attribute,
                           canSet: (AXUIElement, String) -> Bool = { app, key in
                               var value = DarwinBoolean(false)
                               return AXUIElementIsAttributeSettable(app, key as CFString, &value) == .success && value.boolValue
                           },
                           write: (AXUIElement, String, CFTypeRef) -> AXError = { app, key, value in
                               AXUIElementSetAttributeValue(app, key as CFString, value)
                           }) -> [String: Int] {
        let key = "AXEnhancedUserInterface"
        guard let enabled = read(app, key) as? Bool, !enabled, canSet(app, key) else { return [:] }
        return [key: Int(write(app, key, kCFBooleanTrue).rawValue)]
    }
}
