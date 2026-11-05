import AppKit
import ApplicationServices
import CoreServices
import OSLog

struct AccessibilityPermission {
    var registerApplication: () -> OSStatus = {
        LSRegisterURL(Bundle.main.bundleURL as CFURL, true)
    }
    var isTrusted: () -> Bool = { AXIsProcessTrusted() }
    var prompt: () -> Bool = {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    var openSettings: () -> Void = {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @discardableResult func request(showSettings: Bool = false) -> OSStatus {
        // TCC resolves the app's icon/name through Launch Services. Force a
        // refresh in case this path previously held a different bundle identity.
        let result = registerApplication()
        if result != noErr {
            Logger(subsystem: "io.bitsugar.opensesame", category: "permissions")
                .error("Could not register app with Launch Services: \(result)")
        }
        if !isTrusted() { _ = prompt() }
        if showSettings { openSettings() }
        return result
    }
}
