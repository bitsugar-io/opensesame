import AppKit
import ApplicationServices
import OpenSesameCore

struct StackCandidate {
    let place: NavigationPlace
    let live: StackWindowResolver.LiveWindow
}

extension Controller {
    func loadStacks() {
        guard configurationValid, !stacksConfigured else { return }
        do {
            let migrated = NavigationStacks(pins: try stackStore.load())
            try persistStacks(migrated, migrating: true)
            stacks = migrated
        } catch {
            stackSaveError = "Could not migrate saved places: \(error.localizedDescription)"
            message = stackSaveError!
        }
    }

    func currentStackCandidate() -> StackCandidate? {
        guard active, !scanning, !applyingConfiguration, configurationValid, stackPicker == nil, let discovery = lastDiscovery,
              discovery.scopeFrame == nil, let window = discovery.window,
              let app = NSRunningApplication(processIdentifier: owner), let bundleID = app.bundleIdentifier,
              !sectionNavigation.targets.isEmpty, !sectionNavigation.isChoosingTabs else { return nil }
        let region = sectionNavigation.depth > 0 ? sectionNavigation.anchor(in: window.frame) : nil
        // Match a session's actual window, not just its potentially duplicated title.
        let sameWindow = stacks.places.filter { place in
            guard let live = liveStackWindows[place.id], live.owner == owner,
                  CFEqual(live.element, window.element) else { return false }
            return true
        }
        let existing: UUID?
        if let restoredPlaceID { existing = restoredPlaceID }
        else if let region {
            let regions = sameWindow.filter { $0.region != nil }
            existing = region.uniqueMatch(in: regions.compactMap(\.region)).map { regions[$0].id }
        } else { existing = sameWindow.first { $0.region == nil }?.id }
        let id = existing ?? UUID()
        let names = sectionNavigation.regionTargets.compactMap { target -> String? in
            let name = target.metadata.title.isEmpty ? target.metadata.description : target.metadata.title
            return name.isEmpty ? nil : name
        }
        let regionName = sectionNavigation.depth == 0 ? "Window" :
            (names.count <= 3 && !names.isEmpty ? names.joined(separator: " · ") : sectionNavigation.regionDescription(in: window.frame))
        let place = NavigationPlace(id: id,
            window: StackWindow(bundleID: bundleID, title: window.title, identifier: window.identifier),
            appName: app.localizedName ?? bundleID, regionName: regionName, region: region)
        return StackCandidate(place: place, live: .init(owner: owner, element: window.element))
    }

    func saveStack(_ candidate: StackCandidate) throws {
        var updated = stacks
        try updated.save(candidate.place)
        try persistStacks(updated)
        stacks = updated
        liveStackWindows[candidate.place.id] = candidate.live
        stackRemovalUndo = nil
    }
    func saveCurrentStack() {
        guard enabled, trusted, configurationValid else { return }
        guard let candidate = stackCandidate ?? currentStackCandidate() else {
            showStacks(notice: "Open hints in a window and choose the section you want to save first."); return
        }
        do {
            try saveStack(candidate)
            showStacks(notice: "Saved \(candidate.place.appName) · \(candidate.place.regionName).")
            stackCandidate = nil
            stackPicker?.selected = candidate.place.id
        } catch {
            showStacks(notice: "Could not save stack: \(error.localizedDescription)")
            stackCandidate = candidate
        }
    }
    func recordStackVisit(_ id: UUID) {
        var updated = stacks
        updated.visit(id)
        do { try persistStacks(updated); stacks = updated }
        catch { stackSaveError = "Could not save last visit: \(error.localizedDescription)" }
    }
    func showStacks(notice: String? = nil) {
        guard enabled, configurationValid, trusted else { return }
        let candidate = stackCandidate ?? currentStackCandidate()
        closeSettings?()
        cancel(reason: "show-stacks")
        stackCandidate = candidate
        var picker = StackPickerState(entries: stacks.ordered)
        picker.notice = notice ?? stackSaveError
        stackPicker = picker
        active = true
        message = notice ?? "Stacks · type 1–5 to return · \(saveStackShortcut.display) saves the current place"
        redrawStacks()
    }
    func redrawStacks() {
        guard stackPicker != nil else { return }
        stackPanel.show(model: self)
        syncInputRouting()
    }
    func removeStack(_ id: UUID) {
        guard let picker = stackPicker, let place = picker.entries.first(where: { $0.id == id }) else { return }
        var updated = stacks
        updated.remove(id)
        do { try persistStacks(updated) }
        catch { stackPicker?.notice = "Could not remove place: \(error.localizedDescription)"; redrawStacks(); return }
        stackRemovalUndo = (stacks, picker)
        stacks = updated
        stackPicker?.remove(id)
        lifecycle.cancel() // Invalidate queued keys before publishing renumbered choices.
        stackPicker?.notice = "Removed \(place.appName) · \(place.regionName). ⌘Z to undo."
        redrawStacks()
    }
    func undoStackRemoval() {
        guard let undo = stackRemovalUndo else { return }
        do { try persistStacks(undo.stacks) }
        catch { stackPicker?.notice = "Could not restore place: \(error.localizedDescription)"; redrawStacks(); return }
        stacks = undo.stacks; stackPicker = undo.picker; stackRemovalUndo = nil
        lifecycle.cancel()
        stackPicker?.notice = "Restored the removed place."
        redrawStacks()
    }
    func resumeLastStack() {
        guard let place = stacks.last else { showStacks(); return }
        recallStack(place)
    }
    func previousStack() {
        cancel(reason: "previous-stack")
        guard let place = stacks.previous() else { showStacks(notice: "No previous saved place yet. Recall another stack first."); return }
        recallStack(place)
    }
    func recallStack(_ place: NavigationPlace) {
        guard enabled, configurationValid, trusted else { return }
        guard Hints.allows(bundleID: place.window.bundleID, name: place.appName, list: apps, only: only) else {
            showStacks(notice: "\(place.appName) is excluded by your app configuration."); return
        }
        cancel(reason: "recall-stack")
        scanning = true; recallingStack = true
        let ticket = generation
        let live = liveStackWindows[place.id]
        let owners = NSWorkspace.shared.runningApplications.filter {
            !$0.isTerminated && $0.bundleIdentifier == place.window.bundleID
        }.map(\.processIdentifier)
        stackPanel.showNotice("Returning to \(place.appName)…", palette: resolvedPalette)
        syncInputRouting()
        worker.async { [weak self] in
            let resolved = StackWindowResolver.resolve(place.window, live: live, owners: owners, load: { pid in
                let app = AXUIElementCreateApplication(pid)
                AXUIElementSetMessagingTimeout(app, 0.08)
                let windows = attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? []
                for window in windows { AXUIElementSetMessagingTimeout(window, 0.08) }
                return windows
            }, describe: { window in
                StackWindow(bundleID: place.window.bundleID, title: attribute(window, kAXTitleAttribute) as? String ?? "",
                            identifier: attribute(window, kAXIdentifierAttribute) as? String ?? "")
            })
            DispatchQueue.main.async {
                guard let self, self.lifecycle.accepts(generation: ticket), self.enabled, self.trusted else { return }
                guard let resolved, let app = NSRunningApplication(processIdentifier: resolved.owner), !app.isTerminated else {
                    self.showStacks(notice: "That window is closed or cannot be identified uniquely. Open it and visit the place again."); return
                }
                let window = resolved.element
                let axApp = AXUIElementCreateApplication(resolved.owner)
                AXUIElementSetMessagingTimeout(axApp, 0.08)
                if attribute(window, kAXMinimizedAttribute) as? Bool == true {
                    AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                }
                let activated = app.activate(options: [.activateIgnoringOtherApps])
                AXUIElementSetAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, window)
                AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
                let raised = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                guard activated, raised == .success else {
                    self.showStacks(notice: "Could not bring that window forward. Choose another stack or try again."); return
                }
                // Give activation/unminimizing time to settle. Typing or Escape
                // invalidates this generation; no delayed scan may recapture it.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    guard let self, self.lifecycle.accepts(generation: ticket) else { return }
                    guard let focused = attribute(axApp, kAXFocusedWindowAttribute),
                          CFEqual(focused, window) else {
                        self.showStacks(notice: "The saved window did not become active. Choose another stack."); return
                    }
                    self.summon(restoring: place, window: resolved)
                }
            }
        }
    }

    func handleStackKey(_ event: CGEvent, key: Int, modifiers: CGEventFlags) -> Bool {
        if modifiers.intersection([.maskControl, .maskAlternate, .maskCommand, .maskShift]) == .maskCommand {
            if key == 51 { if let id = stackPicker?.selected { removeStack(id) }; return true }
            if key == 6 { undoStackRemoval(); return true }
        }
        guard modifiers.intersection([.maskControl, .maskAlternate, .maskCommand]).isEmpty else {
            cancel(reason: "shortcut-in-stacks"); return false
        }
        guard var picker = stackPicker else { return false }
        switch key {
        case 51:
            if !picker.prefix.isEmpty { picker.prefix.removeLast() }
        case 125, 126, 48:
            picker.move(key == 126 || (key == 48 && modifiers.contains(.maskShift)) ? -1 : 1)
        case 36:
            if let place = picker.entries.first(where: { $0.id == picker.selected }) { recallStack(place) }
            else { lifecycle.cancel(); redrawStacks() }
            return true
        default:
            let raw = NSEvent(cgEvent: event)?.charactersIgnoringModifiers ?? ""
            guard let character = Hints.inputCharacter(raw) else { cancel(reason: "non-code-in-stacks"); return false }
            let candidate = picker.prefix + character
            guard picker.codes.contains(where: { $0.hasPrefix(candidate) }) else { NSSound.beep(); return true }
            picker.prefix = candidate
            if let index = picker.codes.firstIndex(of: candidate) { recallStack(picker.entries[index]); return true }
        }
        if !picker.matchingIndices.contains(where: { picker.entries[$0].id == picker.selected }) {
            picker.selected = picker.matchingIndices.first.map { picker.entries[$0].id }
        }
        stackPicker = picker
        redrawStacks()
        return true
    }
}
