import AppKit
import ApplicationServices
import OpenSesameCore

final class Controller: ObservableObject {
    @Published var theme: AppTheme = .glitch { didSet { refreshAppearance(); saveConfiguration() } }
    @Published var appearanceMode: AppearanceMode = .system { didSet { refreshAppearance(); saveConfiguration() } }
    @Published var customTheme = CustomTheme() { didSet { refreshAppearance(); saveConfiguration() } }
    @Published var shortcut = Shortcut() { didSet { cancel(reason: "shortcut-changed"); onAppearanceChange?(); saveConfiguration() } }
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
    private var keyCharacters: [Int: String] = [:]
    private var keyboardSourceObserver: NSObjectProtocol?
    private var keyboardHook: KeyboardHook?
    private var keyboardHookReady = false
    private var keyboardHookBlocked = false
    private let overlays = Overlays()
    private var targets: [Target] = []
    private var sectionContents: [String: [Target]] = [:]
    private var lastDiscovery: DiscoveryResult?
    private var lastDiscoveryDate: Date?
    private var lastDiscoveryOwner: pid_t?
    private var lastAction: [String: Any]?
    private var followupAttempts: [[String: Any]] = []
    private var actionHistory: [[String: Any]] = []
    private var recentEvents: [[String: Any]] = []
    private var prefix = ""
    private var ledgerPage = 0
    private var scanHistory: [[String: Any]] = []
    private var lifecycle = HintLifecycle()
    private var generation: UUID { lifecycle.generation }
    private var followupID: UUID { lifecycle.followupID }
    private var followingAction: Bool { lifecycle.followingAction }
    private var active = false
    private var scanning = false
    private var owner: pid_t = 0
    private var timer: Timer?
    private let worker = DispatchQueue(label: "io.bitsugar.opensesame.discovery")

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
            // Focus-following tools can activate another app without user input.
            // Keep the session bound to its discovered controls until dismissed.
            if (self.active || self.scanning) && !self.trusted { self.cancel(reason: "accessibility-lost") }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.record("app-activated")
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.cancel(reason: "displays-changed") }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.cancel(preserveFollowup: self.followingAction, reason: "space-changed")
        }
    }
    func requestPermission(showSettings: Bool = true) {
        let result = accessibilityPermission.request(showSettings: showSettings)
        trusted = AXIsProcessTrusted()
        if result != noErr { message = "Could not register OpenSesame with macOS (\(result))." }
    }
    private var hasPagedLedger: Bool { overlays.hasPagedChoices || (lastDiscovery?.scopeFrame != nil && !targets.isEmpty && targets.allSatisfy { $0.metadata.role == "AXMenuItem" }) }
    private func syncInputRouting() {
        keyboardHook?.update(KeyboardRouting.Snapshot(generation: generation, shortcut: shortcut,
            enabled: enabled && configurationValid && trusted, recording: recordingShortcut, active: active,
            pending: scanning || followingAction, labels: targets.map(\.label), canPage: hasPagedLedger, keyCharacters: keyCharacters))
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
        if key == 51 { if !prefix.isEmpty { prefix.removeLast() }; ledgerPage = 0; redraw(); return true }
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
                          "route": target.clicksMenuBarExtra ? "mouse" : "accessibility", "status": "queued"]
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
                    let app = AXUIElementCreateApplication(target.metadata.owner)
                    AXUIElementSetAttributeValue(app, kAXFocusedWindowAttribute as CFString, target.element)
                    AXUIElementSetAttributeValue(target.element, kAXMainAttribute as CFString, kCFBooleanTrue)
                    let raised = AXUIElementPerformAction(target.element, kAXRaiseAction as CFString)
                    let activated = NSRunningApplication(processIdentifier: target.metadata.owner)?.activate(options: [.activateIgnoringOtherApps]) ?? false
                    self.lastAction?["status"] = "window-focus-returned"
                    self.lastAction?["result"] = raised.rawValue
                    self.lastAction?["activated"] = activated
                    self.message = raised == .success && activated ? "Window selected. Hints off; type normally." : "Could not focus that window. Summon fresh hints."
                    return
                }
                let before = visibleSurfaces()
                let frontBefore = NSWorkspace.shared.frontmostApplication?.processIdentifier
                if target.clicksMenuBarExtra {
                    let sent = clickMenuBarExtra(at: CGPoint(x: frame.midX, y: frame.midY))
                    self.lastAction?["status"] = sent ? "mouse-events-posted" : "mouse-events-unavailable"
                    self.message = sent ? "Opening menu bar item…" : "Could not send the menu bar click."
                    if sent, self.generation == actionID { self.refreshAfterAction(target.element, before: before, frontBefore: frontBefore) }
                    return
                }
                let result = AXUIElementPerformAction(target.element, target.action as CFString)
                self.lastAction?["status"] = "accessibility-returned"
                self.lastAction?["result"] = result.rawValue
                guard self.generation == actionID else { return }
                if !target.kind.followsOpenedSurface {
                    self.message = result == .success ? "Done. Hints off; type normally." : "The app declined that action (AX \(result.rawValue)). Hints off."
                    return
                }
                self.message = result == .success ? "Activated. Checking for an opened menu or window…" : "The app declined that action (AX \(result.rawValue)). Try fresh hints."
                // Menu opening may take effect even when AX times out waiting for
                // the app's reply. Detect the resulting surface without retrying the action.
                self.refreshAfterAction(target.element, before: before, frontBefore: frontBefore)
            }
        } else { redraw() }
        return true
    }
    func summon(surface: Surface? = nil, openedFrom: AXUIElement? = nil, followup: UUID? = nil) {
        guard configurationValid else { return }
        var sourcePID: pid_t = 0
        if let openedFrom { AXUIElementGetPid(openedFrom, &sourcePID) }
        let scanApp = surface.flatMap { NSRunningApplication(processIdentifier: $0.pid) }
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
        owner = app.processIdentifier; scanning = true
        syncInputRouting()
        let ticket = generation, pid = owner
        let extras = includeMenuBar ? NSWorkspace.shared.runningApplications.filter {
            $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && Hints.allows(bundleID: $0.bundleIdentifier ?? "", name: $0.localizedName ?? "", list: apps, only: only)
        }.map(\.processIdentifier) : []
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        let screens = NSScreen.screens.map { CGRect(x: $0.frame.minX, y: top - $0.frame.maxY, width: $0.frame.width, height: $0.frame.height) }
        message = "Finding controls…"
        let configuration = hintConfiguration
        worker.async { [weak self] in
            let result = Discovery.scan(pid: pid, extras: extras, screens: screens, surface: surface, openedFrom: openedFrom, configuration: configuration, popupOnly: followup != nil)
            DispatchQueue.main.async {
                guard let self, self.lifecycle.accepts(generation: ticket, followup: followup) else { return }
                self.scanning = false
                self.record("scan-completed-\(result.targets.count)")
                self.lastDiscovery = result
                self.lastDiscoveryDate = Date()
                self.lastDiscoveryOwner = pid
                self.scanHistory.append(self.discoverySnapshot(result, owner: pid, date: self.lastDiscoveryDate))
                if self.scanHistory.count > 8 { self.scanHistory.removeFirst(self.scanHistory.count - 8) }
                let found = result.targets
                if !found.isEmpty, let followup, self.followupID == followup {
                    self.lifecycle.finishFollowup(followup)
                }
                self.targets = self.sectionedTargets(found, scopedPopup: result.scopeFrame != nil); self.active = !found.isEmpty
                self.message = found.isEmpty ? "No accessible press actions found in this app." : "\(found.count) hints · type a label · Esc cancels"
                if found.isEmpty, result.rootResolution == "unmatched-menu-surface" {
                    self.message = "An open popup could not be read. Dismiss it and summon fresh hints."
                } else if found.isEmpty, result.rootProbes.contains(where: { ($0["error"] as? Int32) == AXError.apiDisabled.rawValue }) {
                    self.message = "macOS denied Accessibility access. Re-enable OpenSesame in Accessibility settings."
                }
                if app.bundleIdentifier == "com.spotify.client",
                   !found.contains(where: { $0.metadata.owner == pid && $0.metadata.role != "AXMenuBarItem" && $0.kind != .window }) {
                    self.message = "Spotify has not exposed its window controls to Accessibility. Menu hints are available."
                }
                self.redraw()
            }
        }
    }
    private func refreshAfterAction(_ element: AXUIElement, before: [Surface], frontBefore: pid_t?) {
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
                self.summon(surface: opened, openedFrom: element, followup: ticket)
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
        lifecycle.cancel(preservingFollowup: preserveFollowup)
        active = false; scanning = false; prefix = ""; ledgerPage = 0; targets = []; sectionContents = [:]
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
            "actionHistory": actionHistory, "followupAttempts": followupAttempts, "scanHistory": scanHistory
        ]
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
             "owner": target.metadata.owner, "bundleID": target.metadata.bundleID, "kind": target.kind.rawValue, "frame": rect(target.frame)]
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
        guard let contents = sectionContents[label] else { return false }
        sectionContents = [:]
        let labels = Hints.labels(count: contents.count, configuration: hintConfiguration)
        targets = zip(contents, labels).map { target, label in
            Target(element: target.element, frame: target.frame, label: label, kind: target.kind,
                   action: target.action, clicksMenuBarExtra: target.clicksMenuBarExtra, metadata: target.metadata)
        }
        prefix = ""; ledgerPage = 0
        // The input thread disarmed the completed code. A fresh generation
        // makes the section's new labels available without posting any event.
        lifecycle.cancel(preservingFollowup: false)
        active = true
        message = "\(targets.count) controls in section · type a label · Esc cancels"
        redraw()
        return true
    }
    func sectionedTargets(_ found: [Target], scopedPopup: Bool) -> [Target] {
        sectionContents = [:]
        // Popups are already a focused section. Keep window/menu navigation
        // directly available alongside sections of the crowded window.
        guard !scopedPopup else { return found }
        let controls = found.filter { $0.kind != .window && $0.metadata.role != "AXMenuBarItem" }
        let sections = HintSections.make(frames: controls.map(\.frame))
        guard !sections.isEmpty else { return found }
        let navigation = found.filter { $0.kind == .window || $0.metadata.role == "AXMenuBarItem" }
        let labels = Hints.labels(count: sections.count + navigation.count, configuration: hintConfiguration)
        var result: [Target] = []
        let whole = controls.reduce(CGRect.null) { $0.union($1.frame) }
        for (index, section) in sections.enumerated() {
            let contents = section.indices.map { controls[$0] }
            guard let first = contents.first else { continue }
            let label = labels[index]
            sectionContents[label] = contents
            let vertical = section.frame.midY < whole.minY + whole.height / 3 ? "Upper" : (section.frame.midY > whole.maxY - whole.height / 3 ? "Lower" : "Middle")
            let horizontal = section.frame.midX < whole.minX + whole.width / 3 ? "left" : (section.frame.midX > whole.maxX - whole.width / 3 ? "right" : "center")
            let metadata = TargetMetadata(role: "OpenSesameSection", subrole: "", title: "\(vertical) \(horizontal) · \(contents.count)",
                description: "", owner: first.metadata.owner, bundleID: first.metadata.bundleID)
            result.append(Target(element: first.element, frame: section.frame, label: label, kind: .control,
                action: "", clicksMenuBarExtra: false, metadata: metadata))
        }
        for (index, target) in navigation.enumerated() {
            result.append(Target(element: target.element, frame: target.frame, label: labels[sections.count + index],
                kind: target.kind, action: target.action, clicksMenuBarExtra: target.clicksMenuBarExtra, metadata: target.metadata))
        }
        return result
    }
    private func redraw() {
        syncInputRouting()
        guard active else { overlays.hide(); return }
        overlays.show(targets, prefix: prefix, fontSize: CGFloat(hintSize),
                      scopeFrame: lastDiscovery?.placementFrame, textFrames: lastDiscovery?.textFrames ?? [], palette: resolvedPalette, scopedPopup: lastDiscovery?.scopeFrame != nil, ledgerPage: ledgerPage)
        syncInputRouting()
    }
}
