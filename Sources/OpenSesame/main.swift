import AppKit
import SwiftUI
import OpenSesameBrand
import OpenSesameCore

// Offscreen previews never start the controller or register a running app.
if CommandLine.arguments.dropFirst().first == "--render-previews" {
    guard CommandLine.arguments.count == 3 else {
        fputs("Usage: OpenSesame --render-previews <output-directory>\n", stderr)
        exit(2)
    }
    do {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let directory = URL(fileURLWithPath: CommandLine.arguments[2])
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let model = Controller()
        model.trusted = true
        for page in DashboardPage.allCases {
            let view = NSHostingView(rootView: Dashboard(model: model, page: page))
            view.appearance = NSAppearance(named: .darkAqua)
            view.frame = CGRect(origin: .zero, size: view.fittingSize)
            view.layoutSubtreeIfNeeded()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("settings-\(page.rawValue.lowercased()).png"))
        }
        for theme in AppTheme.allCases {
            model.theme = theme
            for mode in [AppearanceMode.dark, .light] {
                model.appearanceMode = mode
                NSApp.appearance = NSAppearance(named: mode == .dark ? .darkAqua : .aqua)
                let view = NSHostingView(rootView: Dashboard(model: model, page: .style))
                view.appearance = NSAppearance(named: mode == .dark ? .darkAqua : .aqua)
                view.frame = CGRect(origin: .zero, size: view.fittingSize)
                view.layoutSubtreeIfNeeded()
                guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("theme-\(theme.rawValue)-\(mode.rawValue).png"))
            }
        }
        try LayoutPreview.render(to: directory)
        try PopupLayoutPreview.render(to: directory)
        try OverflowPreview.render(to: directory)
    } catch {
        fputs("Preview rendering failed: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
    exit(0)
}

// Development control goes through the running app so visual checks do not
// require synthetic keystrokes or a second Accessibility-authorized process.
let hintControlNotification = Notification.Name("io.bitsugar.opensesame.hint-control")
let hintControlResponse = Notification.Name("io.bitsugar.opensesame.hint-response")
if let command = CommandLine.arguments.dropFirst().first, ["--show-hints", "--hide-hints", "--diagnostics"].contains(command) {
    if command == "--diagnostics" {
        let requestID = UUID().uuidString
        var response: String?
        let observer = DistributedNotificationCenter.default().addObserver(forName: hintControlResponse, object: requestID, queue: .main) { notification in
            response = notification.userInfo?["json"] as? String
        }
        DistributedNotificationCenter.default().postNotificationName(hintControlNotification, object: command, userInfo: ["requestID": requestID], deliverImmediately: true)
        let deadline = Date().addingTimeInterval(3)
        while response == nil && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
        DistributedNotificationCenter.default().removeObserver(observer)
        guard let response else {
            fputs("No diagnostic response. The app may be stopped, busy, or running an older build.\n", stderr)
            exit(1)
        }
        print(response)
    } else {
        DistributedNotificationCenter.default().postNotificationName(hintControlNotification, object: command, userInfo: nil, deliverImmediately: true)
    }
    exit(0)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = Controller()
    private let popover = NSPopover()
    private var status: NSStatusItem!
    private var hintControl: NSObjectProtocol?
    private var appearanceObservation: NSKeyValueObservation?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = BrandArtwork.mark(size: 20)
        NSApp.applicationIconImage = BrandArtwork.appIcon()
        status.button?.target = self; status.button?.action = #selector(toggle)
        status.button?.toolTip = "OpenSesame · Control + Shift + Space"
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: Dashboard(model: model))
        model.closeSettings = { [weak self] in self?.popover.performClose(nil) }
        model.onAppearanceChange = { [weak self] in
            DispatchQueue.main.async { self?.updateAppearance() }
        }
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.updateAppearance()
                self?.model.redrawForAppearance()
            }
        }
        model.start()
        updateAppearance()
        hintControl = DistributedNotificationCenter.default().addObserver(forName: hintControlNotification, object: nil, queue: .main) { [weak self] notification in
            if notification.object as? String == "--show-hints" { self?.model.summon() }
            else if notification.object as? String == "--hide-hints" { self?.model.cancel() }
            else if notification.object as? String == "--diagnostics", let requestID = notification.userInfo?["requestID"] as? String,
                    let self {
                DistributedNotificationCenter.default().postNotificationName(hintControlResponse, object: requestID,
                    userInfo: ["json": self.model.diagnosticsJSON()], deliverImmediately: true)
            }
        }
        // Refresh Launch Services even when already trusted: System Settings
        // resolves the app's name and icon through that registration.
        DispatchQueue.main.async { [weak self] in
            self?.model.requestPermission(showSettings: false)
        }
    }
    private func updateAppearance() {
        let desired: NSAppearance? = model.appearanceMode == .system ? nil : NSAppearance(named: model.appearanceMode == .dark ? .darkAqua : .aqua)
        if NSApp.appearance?.name != desired?.name { NSApp.appearance = desired }
        let palette = model.resolvedPalette
        status.button?.image = BrandArtwork.mark(size: 20, primary: NSColor(rgb: palette.control), secondary: NSColor(rgb: palette.tab))
        status.button?.toolTip = "OpenSesame · \(model.shortcut.display)"
    }
    @objc private func toggle() {
        model.cancel()
        if popover.isShown { popover.performClose(nil) }
        else if let button = status.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
