import ApplicationServices
import Testing
@testable import OpenSesame

@Test func rendererPreparationOnlyRequestsAnAdvertisedWritableDisabledTree() {
    let app = AXUIElementCreateApplication(0)
    var writes = 0
    for (value, writable, expected) in [(false, true, 1), (true, true, 0), (false, false, 0)] {
        writes = 0
        let result = AccessibilityPreparation.enableTree(app, read: { _, key in
            #expect(key == "AXEnhancedUserInterface")
            return value ? kCFBooleanTrue : kCFBooleanFalse
        }, canSet: { _, _ in writable }, write: { target, key, requested in
            #expect(CFEqual(target, app) && key == "AXEnhancedUserInterface" && CFEqual(requested, kCFBooleanTrue))
            writes += 1; return .success
        })
        #expect(writes == expected && result.count == expected)
    }
    let unsupported = AccessibilityPreparation.enableTree(app, read: { _, _ in nil }, canSet: { _, _ in
        Issue.record("Must not probe setters for an absent attribute"); return true
    })
    #expect(unsupported.isEmpty)
}
