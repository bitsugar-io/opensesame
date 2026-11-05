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
}
