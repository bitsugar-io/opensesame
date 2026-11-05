import Foundation
import Testing
@testable import OpenSesame

struct AccessibilityPermissionTests {
    @Test func registersTheCurrentBundleBeforeRequestingAccess() {
        var calls: [String] = []
        let permission = AccessibilityPermission(
            registerApplication: { calls.append("register"); return 0 },
            isTrusted: { calls.append("check"); return false },
            prompt: { calls.append("prompt"); return false },
            openSettings: { calls.append("settings") })
        #expect(permission.request() == 0)
        #expect(calls == ["register", "check", "prompt"])
    }

    @Test func permissionButtonRetriesRequestBeforeOpeningSettings() {
        var calls: [String] = []
        let permission = AccessibilityPermission(
            registerApplication: { calls.append("register"); return 0 },
            isTrusted: { false }, prompt: { calls.append("prompt"); return false },
            openSettings: { calls.append("settings") })
        permission.request(showSettings: true)
        #expect(calls == ["register", "prompt", "settings"])
    }

    @Test func approvedAppsDoNotPromptAgain() {
        var prompts = 0
        let permission = AccessibilityPermission(
            registerApplication: { 0 }, isTrusted: { true },
            prompt: { prompts += 1; return true }, openSettings: {})
        permission.request()
        #expect(prompts == 0)
    }
    @Test @MainActor func retriesRegistrationBeforePrompting() async {
        var attempts = 0
        var waits = 0
        var prompts = 0
        let permission = AccessibilityPermission(
            registerApplication: { attempts += 1; return attempts < 3 ? -10810 : 0 },
            isTrusted: { false }, prompt: { prompts += 1; return false },
            openSettings: {})
        let result = await permission.requestWithRetry(wait: { waits += 1 })
        #expect(result == 0)
        #expect(attempts == 3)
        #expect(waits == 2)
        #expect(prompts == 1)
    }

    @Test @MainActor func persistentFailureIsBoundedAndDoesNotPrompt() async {
        var attempts = 0
        var prompts = 0
        var settings = 0
        let permission = AccessibilityPermission(
            registerApplication: { attempts += 1; return -10810 },
            isTrusted: { false }, prompt: { prompts += 1; return false },
            openSettings: { settings += 1 })
        let result = await permission.requestWithRetry(showSettings: true, wait: {})
        #expect(result == -10810)
        #expect(attempts == 4)
        #expect(prompts == 0)
        #expect(settings == 1)
    }

    @Test @MainActor func cancelledWaitStopsRegistrationRetries() async {
        var attempts = 0
        let permission = AccessibilityPermission(
            registerApplication: { attempts += 1; return -10810 },
            isTrusted: { false }, prompt: { Issue.record("Unexpected prompt"); return false },
            openSettings: { Issue.record("Unexpected settings launch") })
        let result = await permission.requestWithRetry(wait: { throw CancellationError() })
        #expect(result == -10810)
        #expect(attempts == 1)
    }
}
