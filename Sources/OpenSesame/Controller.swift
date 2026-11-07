import AppKit
import ApplicationServices
import OpenSesameCore

final class Controller: ObservableObject {
    @Published var theme: AppTheme = .glitch { didSet { refreshAppearance(); saveConfiguration() } }
    @Published var appearanceMode: AppearanceMode = .system { didSet { refreshAppearance(); saveConfiguration() } }
    @Published var customTheme = CustomTheme() { didSet { refreshAppearance(); saveConfiguration() } }
    @Published var shortcut = Shortcut() { didSet { cancel(reason: "shortcut-changed"); onAppearanceChange?(); saveConfiguration() } }
    @Published var stacksShortcut = Shortcut.stacks { didSet { cancel(reason: "stacks-shortcut-changed"); saveConfiguration() } }
    @Published var saveStackShortcut = Shortcut.saveStack { didSet { cancel(reason: "save-stack-shortcut-changed"); saveConfiguration() } }
    @Published var stackPicker: StackPickerState?
    @Published var stackCandidate: StackCandidate?
    var stacks = NavigationStacks()
    var stacksConfigured = false
    var stackSaveError: String?
    var stackRemovalUndo: (stacks: NavigationStacks, picker: StackPickerState)?
    var liveStackWindows: [UUID: StackWindowResolver.LiveWindow] = [:]
    var restoredPlaceID: UUID?
    var recallingStack = false
    lazy var stackStore = StackStore(url: configurationURL.deletingLastPathComponent().appendingPathComponent("stacks.json"))
    let stackPanel = StackPanel()
    @Published var recordingShortcut = false { didSet { syncInputRouting() } }
    var onAppearanceChange: (() -> Void)?
    func redrawForAppearance() { redraw() }
    let configurationFileOverride: URL?
    init(configurationURL: URL? = nil) { configurationFileOverride = configurationURL }
    var configurationLoaded = false
    var applyingConfiguration = false
    var loadedConfigurationSource: String?
    @Published var configurationValid = true
    @Published private(set) var hintConfiguration = Controller.savedHintConfiguration()
    private static func savedHintConfiguration() -> HintConfiguration {
        let defaults = UserDefaults.standard
        return (try? HintConfiguration(minimumLength: defaults.object(forKey: "hintLength") as? Int ?? 2,
                                       alphabet: defaults.string(forKey: "hintAlphabet") ?? HintConfiguration.defaultAlphabet,
                                       prefix: defaults.string(forKey: "hintPrefix") ?? "")) ?? .standard
    }
    func configureHints(length: Int, alphabet: String, prefix: String) throws {
        let configuration = try HintConfiguration(minimumLength: length, alphabet: alphabet, prefix: prefix)
        hintConfiguration = configuration
        cancel(reason: "hint-settings-changed")
        saveConfiguration()
    }

    @Published var hintSize = min(22.0, max(10.0, UserDefaults.standard.object(forKey: "hintSize") as? Double ?? 16.0)) {
        didSet { redraw(); saveConfiguration() }
    }
    @Published var newApp = ""
    @Published var chromeIcons = false { didSet { cancel(reason: "icon-settings-changed"); saveConfiguration() } }
    @Published var iconAccessMessage = ""
    func configureChromeIcons(_ enabled: Bool) {
        chromeIcons = enabled
        guard enabled, chromeIcons, configurationValid else { iconAccessMessage = ""; return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let status = ChromeIconAdapter.permission(ask: true)
            DispatchQueue.main.async {
                guard let self, self.chromeIcons else { return }
                self.iconAccessMessage = status == noErr ? "Chrome access allowed. Cached website icons appear with fresh hints."
                    : "Using app icons. Allow Chrome in System Settings → Privacy & Security → Automation."
            }
        }
    }
    @Published var enabled = true { didSet { if !enabled { cancel() } } }
    @Published var includeMenuBar = UserDefaults.standard.object(forKey: "menuBar") as? Bool ?? true {
        didSet { cancel(); saveConfiguration() }
    }
    @Published var only = UserDefaults.standard.bool(forKey: "only") {
        didSet { cancel(); saveConfiguration() }
    }
    @Published var apps = UserDefaults.standard.stringArray(forKey: "apps") ?? [] {
        didSet { cancel(); saveConfiguration() }
    }
    @Published var message = "Click the shortcut field to change your hotkey."
    @Published var trusted = AXIsProcessTrusted()
    var closeSettings: (() -> Void)?
    private let accessibilityPermission = AccessibilityPermission()
    private var permissionRegistrationStatus: OSStatus?
    private var keyCharacters: [Int: String] = [:]
    private var keyboardSourceObserver: NSObjectProtocol?
    private var keyboardHook: KeyboardHook?
    private var keyboardHookReady = false
    private var keyboardHookBlocked = false
    private let overlays = Overlays()
    var targets: [Target] = []
    var sectionNavigation = SectionNavigation()
    var lastDiscovery: DiscoveryResult?
    var lastDiscoveryDate: Date?
    var lastDiscoveryOwner: pid_t?
    private var lastAction: [String: Any]?
    private var followupAttempts: [[String: Any]] = []
    private var actionHistory: [[String: Any]] = []
    private var recentEvents: [[String: Any]] = []
    var prefix = ""
    private var ledgerPage = 0
    private var scanHistory: [[String: Any]] = []
    private var sectionHistory: [[String: Any]] = []
    var lifecycle = HintLifecycle()
    var generation: UUID { lifecycle.generation }
    private var followupID: UUID { lifecycle.followupID }
    private var followingAction: Bool { lifecycle.followingAction }
    var active = false
    var scanning = false
    var owner: pid_t = 0
    private var timer: Timer?
    let worker = DispatchQueue(label: "io.bitsugar.opensesame.discovery")

    func start() {
        loadConfigurationAtStartup()
        // App-object timeouts do not propagate to child controls/windows.
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.2)
        keyCharacters = KeyboardCharacters.current()
        keyboardSourceObserver = DistributedNotificationCenter.default().addObserver(forName: KeyboardCharacters.sourceChanged, object: nil, queue: .main) { [weak self] _ in
            self?.keyCharacters = KeyboardCharacters.current()
            self?.cancel(reason: "keyboard-layout-changed")
        }
        installTap()
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.trusted = AXIsProcessTrusted()
            if self.trusted && self.keyboardHook == nil && !self.keyboardHookBlocked { self.installTap() }
            self.syncInputRouting()
            if (self.active || self.scanning) && !self.trusted { self.cancel(reason: "accessibility-lost") }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.record("app-activated")
            // A launched app may activate after an early popup rescan completes.
            // Never leave that old popup's labels floating over the new window.
            if (self.active || self.scanning), self.stackPicker == nil,
               !self.recallingStack, !self.followingAction {
                self.cancel(reason: "active-app-changed")
                self.message = "App changed. Press the shortcut for fresh hints."
            }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.cancel(reason: "displays-changed") }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            if !self.recallingStack { self.cancel(preserveFollowup: self.followingAction, reason: "space-changed") }
        }
    }
    func requestPermission(showSettings: Bool = true) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await self.accessibilityPermission.requestWithRetry(showSettings: showSettings)
            self.permissionRegistrationStatus = result
            self.trusted = AXIsProcessTrusted()
            if result != noErr {
                self.message = "macOS could not register OpenSesame (error \(result)). Use the Accessibility permission button to retry."
            } else if !self.trusted {
                self.message = "Accessibility access requested. Enable OpenSesame in System Settings."
            }
        }
    }
    private var hasPagedLedger: Bool { overlays.hasPagedChoices || (lastDiscovery?.scopeFrame != nil && !targets.isEmpty && targets.allSatisfy { $0.metadata.role == "AXMenuItem" }) }
    func syncInputRouting() {
        keyboardHook?.update(KeyboardRouting.Snapshot(generation: generation, shortcut: shortcut,
            enabled: enabled && configurationValid && trusted, recording: recordingShortcut, active: active,
            pending: scanning || followingAction, labels: stackPicker?.codes ?? targets.map(\.label), canPage: hasPagedLedger, keyCharacters: keyCharacters,
            stacksShortcut: stacksShortcut, saveStackShortcut: saveStackShortcut, stacksOpen: stackPicker != nil, mousePassthroughFrame: stackPanel.eventFrame))
    }
    private func installTap() {
        guard AXIsProcessTrusted(), keyboardHook == nil, !keyboardHookBlocked else { return }
        let hook = KeyboardHook(handle: { [weak self] event, ticket in
            guard let self, ticket == nil || ticket == self.generation else { return }
            _ = self.handle(.keyDown, event)
        }, cancel: { [weak self] reason in
            self?.cancel(reason: reason)
        }, installed: { [weak self] installed in
            guard let self else { return }
            self.keyboardHookReady = installed
            if !installed {
                self.keyboardHookBlocked = true
                self.message = "Keyboard hook unavailable. Check Accessibility permission, then reopen OpenSesame."
            }
        }, disabled: { [weak self] in
            guard let self else { return }
            self.keyboardHookReady = false
            self.keyboardHookBlocked = true
            self.cancel(reason: "event-tap-disabled")
            self.message = "Keyboard capture stopped. Normal input is restored. Reopen OpenSesame to try again."
        })
        keyboardHook = hook
        syncInputRouting()
        hook.start()
    }
    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if recordingShortcut { return false }
        if event.getIntegerValueField(.eventSourceUserData) == 0x4F534D45 { return false }
        guard type == .keyDown else { cancel(reason: "mouse-or-scroll-\(type.rawValue)"); return false }
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        let modifiers = event.flags.intersection([.maskControl, .maskShift, .maskAlternate, .maskCommand])
        // Full-screen screenshots must preserve the overlay. Control optionally
        // copies the capture to the clipboard instead of saving it.
        if key == 20 && modifiers.contains([.maskCommand, .maskShift]) && !modifiers.contains(.maskAlternate) {
            return false
        }
        if key == Int64(stacksShortcut.keyCode), modifiers == stacksShortcut.flags {
            guard enabled else { return false }
            if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return true }
            if stackPicker != nil { cancel(reason: "stacks-hotkey") } else { showStacks() }
            return true
        }
        if key == Int64(shortcut.keyCode) && modifiers == shortcut.flags {
            guard enabled else { return false }
            if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return true }
            if active || scanning { cancel(reason: "hotkey") } else { summon() }
            return true
        }
        guard active || scanning else {
            // Any new key cancels a pending popup scan without consuming typing.
            cancel(reason: "key-during-followup")
            return false
        }
        if key == 53 { cancel(reason: "escape"); return true }
        // While discovery runs, leave normal typing intact and discard the pending scan.
        if scanning { cancel(reason: "key-during-discovery"); return false }
        if key == Int64(saveStackShortcut.keyCode), modifiers == saveStackShortcut.flags {
            if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 { saveCurrentStack() }
            return true
        }
        if stackPicker != nil { return handleStackKey(event, key: Int(key), modifiers: modifiers) }
        if modifiers.isDisjoint(with: [.maskControl, .maskAlternate, .maskCommand]) {
            if key == 49 { showStacks(); return true }
            if key == 36 { resumeLastStack(); return true }
            if key == 51, modifiers.contains(.maskShift) { previousStack(); return true }
        }
        if key == 51 {
            if !prefix.isEmpty { prefix.removeLast() }
            else if sectionNavigation.back() { restoredPlaceID = nil; refreshSectionPage(); return true }
            ledgerPage = 0; redraw(); return true
        }
        if key == 48, hasPagedLedger,
           modifiers.intersection([.maskControl, .maskAlternate, .maskCommand]).isEmpty {
            ledgerPage += modifiers.contains(.maskShift) ? -1 : 1
            redraw()
            return true
        }
        // Labels are displayed uppercase: Shift and Caps Lock must work too.
        guard modifiers.intersection([.maskControl, .maskAlternate, .maskCommand]).isEmpty else {
            cancel(); message = "Hints cancelled by a keyboard shortcut. Release Control, then type the label."; return false
        }
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 8)
        event.keyboardGetUnicodeString(maxStringLength: buffer.count, actualStringLength: &length, unicodeString: &buffer)
        // A session event tap can receive key events with an empty Unicode payload.
        // AppKit translates using the current keyboard layout in that case.
        let raw = String(utf16CodeUnits: buffer, count: min(length, buffer.count))
        let translated = NSEvent(cgEvent: event)?.charactersIgnoringModifiers ?? raw
        guard let text = Hints.inputCharacter(translated) else {
            cancel(); message = "Hints cancelled: that key is not a hint character."; return false
        }
        let candidate = prefix + text
        guard !Hints.matches(prefix: candidate, labels: targets.map(\.label)).isEmpty else { NSSound.beep(); return true }
        ledgerPage = 0
        prefix = candidate
        message = "Typed \(prefix.uppercased()) · complete the hint to activate"
        if let target = targets.first(where: { $0.label == prefix }) {
            if selectSection(target.label) { return true }
            cancel(reason: "hint-selected")
            let actionID = generation
            if let lastAction { actionHistory.append(lastAction) }
            if actionHistory.count > 15 { actionHistory.removeFirst() }
            lastAction = ["id": actionID.uuidString, "selectedAt": ISO8601DateFormatter().string(from: Date()),
                          "hint": target.label, "role": target.metadata.role,
                          "title": target.metadata.title, "description": target.metadata.description,
                          "owner": target.metadata.owner, "action": target.action,
                          "route": target.clicksMenuBarExtra || target.action == TabSelection.groupClick ? "mouse" : "accessibility", "status": "queued"]
            // AX work stays on the UI side of the asynchronous keyboard router.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.lifecycle.accepts(generation: actionID), self.enabled, AXIsProcessTrusted() else {
                    if self.lastAction?["id"] as? String == actionID.uuidString { self.lastAction?["status"] = "cancelled-before-dispatch" }
                    return
                }
                guard NSRunningApplication(processIdentifier: target.metadata.owner)?.isTerminated == false,
                      let frame = elementFrame(target.element), TargetGeometry.isStable(previous: target.frame, current: frame),
                      attribute(target.element, kAXEnabledAttribute) as? Bool != false else {
                    self.lastAction?["status"] = "stale-target"
                    self.message = "That control moved or disappeared. Summon fresh hints."; return
                }
                if target.kind == .window {
                    let transition = self.lifecycle.beginFollowup()
                    self.scanning = true
                    self.syncInputRouting()
                    let app = AXUIElementCreateApplication(target.metadata.owner)
                    AXUIElementSetMessagingTimeout(app, 0.08)
                    let activated = NSRunningApplication(processIdentifier: target.metadata.owner)?.activate(options: [.activateIgnoringOtherApps]) ?? false
                    AXUIElementSetAttributeValue(app, kAXFocusedWindowAttribute as CFString, target.element)
                    AXUIElementSetAttributeValue(target.element, kAXMainAttribute as CFString, kCFBooleanTrue)
                    let raised = AXUIElementPerformAction(target.element, kAXRaiseAction as CFString)
                    self.lastAction?["status"] = "window-focus-returned"
                    self.lastAction?["result"] = raised.rawValue
                    self.lastAction?["activated"] = activated
                    guard activated else {
                        self.cancel(reason: "window-activation-failed")
                        self.message = "Could not focus that window. Summon fresh hints."
                        return
                    }
                    self.message = "Finding controls in the selected window…"
                    self.refreshSelectedWindow(.init(owner: target.metadata.owner, element: target.element), transition: transition)
                    return
                }
                let before = visibleSurfaces()
                let frontBefore = NSWorkspace.shared.frontmostApplication?.processIdentifier
                if target.clicksMenuBarExtra {
                    let sent = clickPrimaryTarget(at: CGPoint(x: frame.midX, y: frame.midY))
                    self.lastAction?["status"] = sent ? "mouse-events-posted" : "mouse-events-unavailable"
                    self.message = sent ? "Opening menu bar item…" : "Could not send the menu bar click."
                    if sent, self.generation == actionID { self.refreshAfterAction(target.element, before: before, frontBefore: frontBefore, menuBarAction: target.metadata.role == "AXMenuBarItem") }
                    return
                }
                if target.action == TabSelection.groupClick {
                    let outcome = TabSelection.clickGroup(target, frame: frame)
                    self.lastAction?["status"] = outcome.reason
                    self.lastAction?["details"] = outcome.details
                    self.message = outcome.posted ? "Updating tab choices…" : "That group is covered or changed. Summon fresh hints."
                    if outcome.posted { self.refreshAfterTabSelection(target) }
                    return
                }
                let result = AccessibilityActions.perform(target)
                self.lastAction?["status"] = "accessibility-returned"
                self.lastAction?["result"] = result.rawValue
                guard self.generation == actionID else { return }
                if target.kind == .tab {
                    if result == .success { self.refreshAfterTabSelection(target) }
                    else { self.message = "The app declined tab selection (AX \(result.rawValue)). Summon fresh hints." }
                    return
                }
                if target.metadata.isDisclosure || target.kind == .desktop {
                    self.refreshAfterDisclosure(target, frontBefore: frontBefore)
                    return
                }
                if !target.kind.followsOpenedSurface && target.action != kAXShowMenuAction {
                    self.message = result == .success ? "Done. Hints off; type normally." : "The app declined that action (AX \(result.rawValue)). Hints off."
                    return
                }
                self.message = result == .success ? "Activated. Checking for an opened menu or window…" : "The app declined that action (AX \(result.rawValue)). Try fresh hints."
                // Menu opening may take effect even when AX times out waiting for
                // the app's reply. Detect the resulting surface without retrying the action.
                self.refreshAfterAction(target.element, before: before, frontBefore: frontBefore, menuBarAction: target.metadata.role == "AXMenuBarItem")
            }
        } else { redraw() }
        return true
    }
    private func refreshSelectedWindow(_ window: StackWindowResolver.Resolved, transition: UUID) {
        // Activate once, then observe focus as the window settles. Cancellation
        // invalidates every pending attempt, including an in-flight scan.
        WindowSelection.waitForFocus(isCurrent: { [weak self] in
            guard let self else { return false }
            return self.followingAction && self.followupID == transition && self.enabled && self.trusted
        }, focused: { WindowSelection.isFocused(window) }, refresh: { [weak self] in
            self?.summon(followup: transition, window: window)
        }, unavailable: { [weak self] in
            self?.cancel(reason: "selected-window-not-focused")
            self?.message = "That window did not become active. Summon fresh hints."
        })
    }
    private func refreshAfterDisclosure(_ target: Target, frontBefore: pid_t?) {
        // A disclosure changes the existing surface, not necessarily its window.
        // Observe the fresh tree once; never replay an action after an AX timeout.
        let ticket = lifecycle.beginFollowup()
        syncInputRouting()
        message = "Refreshing choices…"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.followupID == ticket, self.enabled, self.trusted else { return }
            let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
            self.lifecycle.finishFollowup(ticket)
            guard front == frontBefore || front == target.metadata.owner else {
                self.cancel(reason: "disclosure-owner-changed"); return
            }
            self.summon()
        }
    }
    func summon(surface: Surface? = nil, openedFrom: AXUIElement? = nil, followup: UUID? = nil, restoring: NavigationPlace? = nil, window: StackWindowResolver.Resolved? = nil, menuBarFallback: Bool = false, tabSelection: TabSelection = .none) {
        guard configurationValid else { return }
        var sourcePID: pid_t = 0
        if let openedFrom { AXUIElementGetPid(openedFrom, &sourcePID) }
        let scanApp = window.flatMap { NSRunningApplication(processIdentifier: $0.owner) } ?? surface.flatMap { NSRunningApplication(processIdentifier: $0.pid) }
            ?? (sourcePID != 0 ? NSRunningApplication(processIdentifier: sourcePID) : nil)
            ?? NSWorkspace.shared.frontmostApplication
        guard enabled, AXIsProcessTrusted(), let app = scanApp,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            message = "Focus another app first; Accessibility permission is required."; return
        }
        guard Hints.allows(bundleID: app.bundleIdentifier ?? "", name: app.localizedName ?? "", list: apps, only: only) else {
            message = "\(app.localizedName ?? "This app") is excluded."; return
        }
        closeSettings?()
        cancel(preserveFollowup: followup != nil, reason: "scan-started")
        owner = app.processIdentifier; scanning = true; recallingStack = restoring != nil
        syncInputRouting()
        let ticket = generation, pid = owner
        let allowedApps = NSWorkspace.shared.runningApplications.filter {
            $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && Hints.allows(bundleID: $0.bundleIdentifier ?? "", name: $0.localizedName ?? "", list: apps, only: only)
        }.map(\.processIdentifier)
        let extras = includeMenuBar ? allowedApps : []
        let windowOwners = Set(allowedApps)
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        let screens = NSScreen.screens.map { CGRect(x: $0.frame.minX, y: top - $0.frame.maxY, width: $0.frame.width, height: $0.frame.height) }
        message = "Finding controls…"
        let configuration = hintConfiguration
        let useChromeIcons = chromeIcons
        worker.async { [weak self] in
            var result = Discovery.scan(pid: pid, extras: extras, screens: screens, surface: surface, openedFrom: openedFrom, configuration: configuration, popupOnly: followup != nil && window == nil, menuBarFallback: menuBarFallback, windowOwners: windowOwners, requestedWindow: window?.element)
            if useChromeIcons, let frame = result.window?.frame {
                result.targets = ChromeIconAdapter.enrich(result.targets, window: frame)
            }
            DispatchQueue.main.async {
                guard let self, self.lifecycle.accepts(generation: ticket, followup: followup) else { return }
                if let window, !WindowSelection.isFocused(window) {
                    self.cancel(reason: "selected-window-changed-during-scan")
                    return
                }
                self.scanning = false
                self.recallingStack = false
                self.record("scan-completed-\(result.targets.count)")
                self.lastDiscovery = result
                self.lastDiscoveryDate = Date()
                self.lastDiscoveryOwner = pid
                self.scanHistory.append(self.discoverySnapshot(result, owner: pid, date: self.lastDiscoveryDate))
                if self.scanHistory.count > 8 { self.scanHistory.removeFirst(self.scanHistory.count - 8) }
                let found = result.targets
                if (!found.isEmpty || window != nil), let followup, self.followupID == followup {
                    self.lifecycle.finishFollowup(followup)
                }
                self.targets = self.sectionedTargets(found, scopedPopup: result.scopeFrame != nil, windowFrame: result.window?.frame, tabSelection: tabSelection); self.active = !found.isEmpty
                self.message = found.isEmpty ? "No accessible press actions found in this app." : "\(found.count) hints · type a label · Esc cancels"
                if self.sectionNavigation.sectionCount > 0 {
                    self.message = "\(self.sectionNavigation.sectionCount) sections · type a label to narrow the choices · Esc cancels"
                }
                if found.isEmpty, result.rootResolution == "unmatched-menu-surface" {
                    self.message = "An open popup could not be read. Dismiss it and summon fresh hints."
                } else if found.isEmpty, result.rootProbes.contains(where: { ($0["error"] as? Int32) == AXError.apiDisabled.rawValue }) {
                    self.message = "macOS denied Accessibility access. Re-enable OpenSesame in Accessibility settings."
                }
                if app.bundleIdentifier == "com.spotify.client",
                   !found.contains(where: { $0.metadata.owner == pid && $0.metadata.role != "AXMenuBarItem" && $0.kind != .window }) {
                    self.message = "Spotify has not exposed its window controls to Accessibility. Menu hints are available."
                }
                if let restoring {
                    guard let discovered = result.window, let window, CFEqual(discovered.element, window.element) else {
                        self.showStacks(notice: "That window is no longer available. Choose another stack."); return
                    }
                    guard !found.isEmpty else {
                        self.showStacks(notice: "No accessible controls were found in that window. Open its content and try again."); return
                    }
                    let restored = !result.reachedLimit && (restoring.region.map {
                        self.sectionNavigation.restore($0, window: discovered.frame, configuration: configuration)
                    } ?? true)
                    self.targets = self.sectionNavigation.targets
                    self.restoredPlaceID = restored ? restoring.id : nil
                    self.liveStackWindows[restoring.id] = .init(owner: pid, element: discovered.element)
                    if restored { self.recordStackVisit(restoring.id) }
                    self.message = restored ? "\(restoring.appName) · \(restoring.regionName) · type a label · Backspace goes up" : "Saved region changed. Showing this window’s current choices."
                    if !restored { self.stackPanel.showNotice(self.message, palette: self.resolvedPalette) }
                }
                self.redraw()
            }
        }
    }
    private func refreshAfterAction(_ element: AXUIElement, before: [Surface], frontBefore: pid_t?, menuBarAction: Bool = false) {
        var targetPID: pid_t = 0
        guard AXUIElementGetPid(element, &targetPID) == .success else { return }
        let ticket = lifecycle.beginFollowup()
        syncInputRouting()
        followupAttempts = []
        let sourcePopup: Surface?
        if let scope = lastDiscovery?.scopeFrame {
            sourcePopup = before.first { $0.pid == targetPID && approximatelyEqual($0.frame, scope) }
        } else { sourcePopup = nil }
        // Retry while animations or newly launched apps settle. An intervening
        // key, click, summon, or cancellation invalidates every pending attempt.
        for delay in [0.2, 0.5, 0.9, 1.5, 2.5, 4.0, 6.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.followupID == ticket, !self.scanning, self.enabled, AXIsProcessTrusted(),
                      let front = NSWorkspace.shared.frontmostApplication else { return }
                let allowed = Set([targetPID, front.processIdentifier])
                let after = visibleSurfaces()
                let changed = Surface.opened(before: before, after: after, owners: allowed,
                                             activatedOwner: front.processIdentifier != frontBefore ? front.processIdentifier : nil)
                // Any popup provider can replace contents without creating a
                // window. Reuse only the previously scoped popup, never the
                // background app's ordinary window.
                let continuation = delay >= 0.5 ? sourcePopup.flatMap { previous in
                    after.first { $0.id == previous.id && $0.pid == previous.pid }
                } : nil
                let opened = changed ?? continuation
                func summary(_ surface: Surface) -> [String: Any] {
                    ["id": surface.id, "owner": surface.pid, "layer": surface.layer,
                     "x": surface.frame.minX, "y": surface.frame.minY,
                     "width": surface.frame.width, "height": surface.frame.height]
                }
                var attempt: [String: Any] = ["at": ISO8601DateFormatter().string(from: Date()),
                    "delay": delay, "allowedOwners": Array(allowed), "before": before.prefix(64).map(summary),
                    "after": after.prefix(64).map(summary), "selection": changed != nil ? "changed-surface" : (continuation != nil ? "same-popup" : "ax-popup-probe")]
                if let opened { attempt["selected"] = summary(opened) }
                self.followupAttempts.append(attempt)
                let popupApp = NSRunningApplication(processIdentifier: opened?.pid ?? targetPID)
                guard Hints.allows(bundleID: popupApp?.bundleIdentifier ?? "", name: popupApp?.localizedName ?? "", list: self.apps, only: self.only) else { return }
                // Even without a WindowServer change, query explicitly shown
                // AX menus/dialogs. A popup-only scan never substitutes the
                // background app if no popup actually opened.
                self.summon(surface: opened, openedFrom: element, followup: ticket, menuBarFallback: menuBarAction && delay >= 0.5)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self, self.followupID == ticket else { return }
            self.cancel(reason: "followup-expired")
            self.message = "No opened controls became ready. Press the shortcut to try again."
        }
    }
    private func record(_ event: String) {
        recentEvents.append(["at": ISO8601DateFormatter().string(from: Date()), "event": event,
                             "active": active, "scanning": scanning, "followingAction": followingAction,
                             "visiblePanels": overlays.visiblePanelCount,
                             "frontOwner": NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0])
        if recentEvents.count > 40 { recentEvents.removeFirst(recentEvents.count - 40) }
    }
    func cancel(preserveFollowup: Bool = false, reason: String = "cancelled") {
        if active || scanning || followingAction { record(reason) }
        stackPicker = nil; stackCandidate = nil; stackRemovalUndo = nil; stackPanel.hide(); restoredPlaceID = nil; recallingStack = false
        lifecycle.cancel(preservingFollowup: preserveFollowup)
        active = false; scanning = false; prefix = ""; ledgerPage = 0; targets = []; sectionNavigation.clear()
        syncInputRouting()
        overlays.hide()
    }
    func diagnosticsJSON() -> String {
        var snapshot: [String: Any] = [
            "build": Bundle.main.object(forInfoDictionaryKey: "OpenSesameBuildFingerprint") as? String ?? "unbundled",
            "pid": ProcessInfo.processInfo.processIdentifier,
            "accessibility": AXIsProcessTrusted(), "enabled": enabled,
            "keyboardHook": keyboardHookReady, "shortcut": shortcut.display, "recordingShortcut": recordingShortcut, "configurationValid": configurationValid, "active": active, "scanning": scanning,
            "targetCount": targets.count, "message": message,
            "hintConfiguration": ["minimumLength": hintConfiguration.minimumLength, "alphabet": hintConfiguration.alphabet, "prefix": hintConfiguration.prefix],
            "visiblePanels": overlays.visiblePanelCount, "recentEvents": recentEvents,
            "actionHistory": actionHistory, "followupAttempts": followupAttempts, "scanHistory": scanHistory,
            "sectionHistory": sectionHistory, "sectionDepth": sectionNavigation.depth,
            "stacksShortcut": stacksShortcut.display, "stacksOpen": stackPicker != nil,
            "stackCount": stacks.places.count, "pinnedStackCount": stacks.pins.count
        ]
        if let permissionRegistrationStatus { snapshot["permissionRegistrationStatus"] = permissionRegistrationStatus }
        if let lastAction { snapshot["lastAction"] = lastAction }
        if let discovery = lastDiscovery {
            snapshot["lastScan"] = discoverySnapshot(discovery, owner: lastDiscoveryOwner, date: lastDiscoveryDate)
        }
        guard let data = try? JSONSerialization.data(withJSONObject: snapshot, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }
    private func discoverySnapshot(_ discovery: DiscoveryResult, owner: pid_t?, date: Date?) -> [String: Any] {
        func rect(_ frame: CGRect) -> [String: Double] {
            ["x": Double(frame.minX), "y": Double(frame.minY), "width": Double(frame.width), "height": Double(frame.height)]
        }
        let rows: [[String: Any]] = discovery.targets.prefix(256).map { target in
            ["hint": target.label, "role": target.metadata.role, "subrole": target.metadata.subrole,
             "title": target.metadata.title, "description": target.metadata.description,
             "owner": target.metadata.owner, "bundleID": target.metadata.bundleID, "kind": target.kind.rawValue, "action": target.action, "frame": rect(target.frame)]
        }
        var scan: [String: Any] = ["targets": rows, "targetCount": discovery.targets.count, "rootRoles": discovery.rootRoles,
            "accessibilityPreparation": discovery.accessibilityPreparation, "rootProbes": discovery.rootProbes, "rootResolution": discovery.rootResolution, "rejected": discovery.rejected,
            "visitedNodes": discovery.visitedNodes, "reachedLimit": discovery.reachedLimit, "elapsedSeconds": discovery.elapsed]
        if let date { scan["completedAt"] = ISO8601DateFormatter().string(from: date) }
        if let owner { scan["owner"] = owner }
        if let frame = discovery.scopeFrame { scan["scopeFrame"] = rect(frame) }
        return scan
    }
    @discardableResult
    func selectSection(_ label: String) -> Bool {
        guard sectionNavigation.select(label, configuration: hintConfiguration) else { return false }
        restoredPlaceID = nil
        refreshSectionPage()
        sectionHistory.append(["selected": label, "depth": sectionNavigation.depth,
            "sectionCount": sectionNavigation.sectionCount, "at": ISO8601DateFormatter().string(from: Date()),
            "choices": targets.prefix(256).map { target in
                ["hint": target.label, "role": target.metadata.role, "action": target.action,
                 "title": target.metadata.title, "description": target.metadata.description,
                 "frame": ["x": target.frame.minX, "y": target.frame.minY, "width": target.frame.width, "height": target.frame.height]] as [String: Any]
            }])
        if sectionHistory.count > 12 { sectionHistory.removeFirst(sectionHistory.count - 12) }
        return true
    }
    private func refreshSectionPage() {
        targets = sectionNavigation.targets
        prefix = ""; ledgerPage = 0
        // Each level gets a new input generation after a completed code.
        // Only the UI-side handler changes pages; input callbacks stay bounded.
        lifecycle.cancel(preservingFollowup: false)
        active = true
        let choices = sectionNavigation.sectionCount > 0 ? "\(sectionNavigation.sectionCount) sections" : "\(targets.count) controls"
        let back = sectionNavigation.canGoBack ? " · Backspace goes back" : ""
        message = "\(choices) · type a label\(back) · Esc cancels"
        redraw()
    }
    func sectionedTargets(_ found: [Target], scopedPopup: Bool, windowFrame: CGRect? = nil, tabSelection: TabSelection = .none) -> [Target] {
        sectionNavigation.reset(found, scopedPopup: scopedPopup, configuration: hintConfiguration, windowFrame: windowFrame, tabSelection: tabSelection)
    }
    func redraw() {
        syncInputRouting()
        if stackPicker != nil { overlays.hide(); redrawStacks(); return }
        guard active else { overlays.hide(); return }
        let app = NSRunningApplication(processIdentifier: owner)
        overlays.show(targets, prefix: prefix, fontSize: CGFloat(hintSize),
                      scopeFrame: sectionNavigation.scopeFrame ?? lastDiscovery?.placementFrame, textFrames: lastDiscovery?.textFrames ?? [], palette: resolvedPalette,
                      scopedPopup: lastDiscovery?.scopeFrame != nil, ledgerPage: ledgerPage,
                      prefersActionPanel: sectionNavigation.prefersActionPanel, canGoBack: sectionNavigation.canGoBack,
                      windowFrame: lastDiscovery?.window?.frame, appName: app?.localizedName ?? "",
                      appIcon: app.map { AppIdentity.icon(bundleID: $0.bundleIdentifier ?? "") }, owner: owner)
        syncInputRouting()
    }
}
