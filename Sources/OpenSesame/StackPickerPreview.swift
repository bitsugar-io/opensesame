#if DEBUG
import AppKit
import SwiftUI
import OpenSesameCore
import ApplicationServices

enum StackPickerPreview {
    static func render(to directory: URL) throws {
        for dark in [false, true] {
            for variant in ["places", "empty", "unavailable", "narrow", "current", "full", "removed"] {
                let model = Controller()
                model.appearanceMode = dark ? .dark : .light
                model.trusted = true
                let entries = (0..<(variant == "empty" ? 0 : 5)).map { index in
                    NavigationPlace(window: StackWindow(bundleID: ["com.apple.Music", "com.apple.Terminal", "com.apple.Notes"][index % 3], title: ["Music window", "Project terminal", "Reference notes", "Library", "Build output"][index]),
                        appName: ["Music", "Terminal", "Notes"][index % 3],
                        regionName: ["Playback", "Editor", "Reading pane", "Library", "Output"][index], region: nil, pinned: variant == "full" || index < 2)
                }
                var picker = StackPickerState(entries: entries)
                if variant == "current" || variant == "narrow" {
                    picker.selected = entries[2].id
                    model.stackCandidate = .init(place: entries[2], live: .init(owner: 0, element: AXUIElementCreateApplication(0)))
                }
                if variant == "removed" { picker.remove(entries[1].id); picker.notice = "Removed Terminal · Editor. ⌘Z to undo." }
                if variant == "unavailable" { picker.notice = "That window is closed or cannot be identified uniquely. Open it and visit the place again." }
                model.stackPicker = picker
                let view = NSHostingView(rootView: StackPickerView(model: model))
                view.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                view.frame = CGRect(x: 0, y: 0, width: variant == "narrow" ? 400 : 640, height: 608)
                view.layoutSubtreeIfNeeded()
                guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw CocoaError(.coderInvalidValue) }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                try bitmap.representation(using: .png, properties: [:])!.write(to:
                    directory.appendingPathComponent("stacks-\(variant)-\(dark ? "dark" : "light").png"))
            }
        }
    }
}
#endif
