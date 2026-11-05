import AppKit
import SwiftUI
import OpenSesameCore

extension Shortcut {
    var flags: CGEventFlags {
        modifiers.reduce(CGEventFlags()) { result, modifier in
            result.union(["control": .maskControl, "shift": .maskShift, "option": .maskAlternate, "command": .maskCommand][modifier] ?? [])
        }
    }
    static func recorded(from event: NSEvent) throws -> Self {
        let flags = event.modifierFlags.intersection([.control, .shift, .option, .command])
        let modifiers = [("control", NSEvent.ModifierFlags.control), ("option", .option), ("shift", .shift), ("command", .command)]
            .filter { flags.contains($0.1) }.map(\.0)
        let names: [UInt16: String] = [49: "Space", 36: "Return", 48: "Tab", 51: "Delete", 123: "←", 124: "→", 125: "↓", 126: "↑"]
        let key = names[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? ""
        return try Shortcut(keyCode: Int(event.keyCode), modifiers: modifiers, key: key).validated()
    }
}
struct ShortcutRecorder: NSViewRepresentable {
    @ObservedObject var model: Controller
    func makeNSView(context: Context) -> RecorderButton { RecorderButton(model: model) }
    func updateNSView(_ button: RecorderButton, context: Context) {
        button.model = model
        button.isEnabled = context.environment.isEnabled && model.configurationValid
        if !button.isEnabled { button.stop() }
        button.title = model.recordingShortcut ? "Press shortcut…" : model.shortcut.display
        button.refreshTitle()
    }
}
final class RecorderButton: NSButton {
    weak var model: Controller?
    private var monitor: Any?
    private var windowObserver: NSObjectProtocol?
    init(model: Controller) {
        self.model = model
        super.init(frame: .zero)
        bezelStyle = .rounded
        isBordered = false; wantsLayer = true; layer?.cornerRadius = 6
        font = .systemFont(ofSize: 15, weight: .semibold)
        target = self; action = #selector(record)
        setAccessibilityLabel("Record keyboard shortcut")
        toolTip = "Click, then press a shortcut. Escape cancels."
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { stop() }
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil { stop() }
        super.viewWillMove(toWindow: newWindow)
    }
    @objc private func record() {
        guard let model, model.configurationValid, isEnabled else { return }
        if model.recordingShortcut { stop(); return }
        model.cancel(reason: "record-shortcut"); model.recordingShortcut = true
        refreshTitle()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in self?.accept(event) ?? (self == nil ? event : nil) }
        windowObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in self?.stop() }
    }
    func accept(_ event: NSEvent) -> NSEvent? {
        guard model?.recordingShortcut == true, model?.configurationValid == true, isEnabled else { stop(); return nil }
        if event.keyCode == 53 { stop(); return nil }
        if event.isARepeat { return nil }
        do {
            let shortcut = try Shortcut.recorded(from: event)
            model?.shortcut = shortcut
            stop()
            if model?.configurationValid == true { model?.message = "Shortcut saved: \(model?.shortcut.display ?? "")." }
        } catch { model?.message = error.localizedDescription }
        return nil
    }
    func refreshTitle() {
        guard let model else { return }
        let color = NSColor(rgb: model.resolvedPalette.control)
        let title = model.recordingShortcut ? "Press shortcut…" : model.shortcut.display
        attributedTitle = NSAttributedString(string: title, attributes: [.foregroundColor: color, .font: NSFont.systemFont(ofSize: 15, weight: .semibold)])
        layer?.backgroundColor = color.withAlphaComponent(0.1).cgColor
    }
    fileprivate func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil
        if let windowObserver { NotificationCenter.default.removeObserver(windowObserver) }; windowObserver = nil
        model?.recordingShortcut = false
        refreshTitle()
    }
}
