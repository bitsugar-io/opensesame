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

    // Launch Services can be temporarily unavailable during startup. Keep the
    // retries asynchronous so permission setup never blocks the menu bar.
    @MainActor
    @discardableResult func requestWithRetry(
        showSettings: Bool = false,
        wait: () async throws -> Void = { try await Task.sleep(nanoseconds: 1_000_000_000) }
    ) async -> OSStatus {
        var result: OSStatus = noErr
        for attempt in 0..<4 {
            if Task.isCancelled { return result }
            result = request()
            if result == noErr { break }
            if attempt < 3 {
                do { try await wait() }
                catch { return result }
            }
        }
        if showSettings { openSettings() }
        return result
    }

    @discardableResult func request(showSettings: Bool = false) -> OSStatus {
        // TCC resolves the app's icon/name through Launch Services. Force a
        // refresh in case this path previously held a different bundle identity.
        let result = registerApplication()
        if result != noErr {
            Logger(subsystem: "io.bitsugar.opensesame", category: "permissions")
                .error("Could not register app with Launch Services: \(result)")
        }
        if result == noErr && !isTrusted() { _ = prompt() }
        if showSettings { openSettings() }
        return result
    }
}
