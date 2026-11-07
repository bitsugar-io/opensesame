import AppKit
import SwiftUI
import OpenSesameCore
import OpenSesameBrand

final class StackPanel {
    private var panel: NSPanel?
    private var pickerVisible = false
    var eventFrame: CGRect? {
        guard let panel, panel.isVisible else { return nil }
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        return CGRect(x: panel.frame.minX, y: top - panel.frame.maxY, width: panel.frame.width, height: panel.frame.height)
    }
    func hide() { panel?.orderOut(nil); panel = nil; pickerVisible = false }
    private func present<Content: View>(_ content: Content, notice: Bool = false) {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let screen else { return }
        let area = screen.visibleFrame.insetBy(dx: 16, dy: 16)
        let host = NSHostingView(rootView: content)
        let size = CGSize(width: min(640, area.width), height: min(notice ? 88 : 608, area.height))
        host.frame = CGRect(origin: .zero, size: size)
        if panel == nil {
            let panel = NSPanel(contentRect: host.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .popUpMenu; panel.hasShadow = true; panel.isOpaque = false; panel.backgroundColor = .clear
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
            self.panel = panel
        }
        panel?.contentView = host
        panel?.setFrame(CGRect(x: area.midX - size.width / 2, y: notice ? area.maxY - size.height : area.midY - size.height / 2,
                              width: size.width, height: size.height), display: true)
        panel?.orderFrontRegardless()
    }
    func show(model: Controller) {
        guard !pickerVisible else { return }
        present(StackPickerView(model: model))
        pickerVisible = true
    }
    func showNotice(_ message: String, palette: ThemePalette) {
        pickerVisible = false
        present(Text(message).font(.system(size: 13, weight: .medium)).padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(Color(nsColor: NSColor(rgb: palette.text)))
            .background(Color(nsColor: NSColor(rgb: palette.background)), in: RoundedRectangle(cornerRadius: 12)), notice: true)
    }
}

struct StackPickerView: View {
    @ObservedObject var model: Controller
    private var palette: ThemePalette { model.resolvedPalette }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Stacks", systemImage: "square.stack.3d.up").font(.system(size: 20, weight: .semibold))
                Spacer()
                Text(model.stacksShortcut.display).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                Button { model.cancel(reason: "close-stacks") } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).accessibilityLabel("Dismiss stacks")
            }
            Text("Only places you save. Press 1–5 to return.")
                .font(.system(size: 13)).foregroundStyle(.secondary)
            if let picker = model.stackPicker {
                if let notice = picker.notice {
                    Text(notice).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: NSColor(rgb: palette.tab)).opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                        .accessibilityLabel(notice)
                }
                if let candidate = model.stackCandidate {
                    HStack(spacing: 12) {
                        Image(nsImage: AppIdentity.icon(bundleID: candidate.place.window.bundleID))
                            .resizable().scaledToFit().frame(width: 24, height: 24).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Save \(candidate.place.appName) · \(candidate.place.regionName)")
                                .font(.system(size: 13, weight: .medium)).lineLimit(2)
                            Text(model.saveStackShortcut.display).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Button(picker.entries.contains(where: { $0.id == candidate.place.id }) ? "Update" : "Save") { model.saveCurrentStack() }
                            .accessibilityLabel("Save current place to stacks")
                    }.padding(12).background(Color(nsColor: NSColor(rgb: palette.surface)), in: RoundedRectangle(cornerRadius: 8))
                }
                if picker.entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.stack.3d.up").font(.system(size: 32)).foregroundStyle(.secondary)
                        Text("No saved places yet").font(.system(size: 16, weight: .semibold))
                        Text("Open hints and choose the section you want.\nPress \(model.saveStackShortcut.display) to save it here.")
                            .font(.system(size: 13)).multilineTextAlignment(.center).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(picker.matchingIndices, id: \.self) { index in
                                    row(picker.entries[index], code: picker.codes[index], selected: picker.selected == picker.entries[index].id,
                                        prefix: picker.prefix).id(picker.entries[index].id)
                                }
                            }.padding(2)
                        }
                        .onChange(of: picker.selected) { id in if let id { proxy.scrollTo(id, anchor: .center) } }
                    }
                }
                if picker.entries.count == NavigationStacks.capacity,
                   let candidate = model.stackCandidate, !picker.entries.contains(where: { $0.id == candidate.place.id }) {
                    Text("All five stacks are filled. Remove one before saving another.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Divider()
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) {
                        Text("↑ ↓ Choose")
                        Text("↩ Return")
                        Text("⌘⌫ Remove")
                        Text("Esc Dismiss")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 16) { Text("↑ ↓ Choose"); Text("↩ Return") }
                        HStack(spacing: 16) { Text("⌘⌫ Remove"); Text("Esc Dismiss") }
                    }
                }.font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Text("Press a displayed number to return directly.")
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .foregroundStyle(Color(nsColor: NSColor(rgb: palette.text)))
        .background(Color(nsColor: NSColor(rgb: palette.background)), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(nsColor: NSColor(rgb: palette.text)).opacity(0.25), lineWidth: 1))
        .environment(\.colorScheme, model.appearanceMode.isDark(systemIsDark: NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua) ? .dark : .light)
    }
    private func row(_ place: NavigationPlace, code: String, selected: Bool, prefix: String) -> some View {
        HStack(spacing: 12) {
            Button { model.recallStack(place) } label: {
                HStack(spacing: 16) {
                    StackCode(code: code, prefix: prefix, palette: palette)
                        .frame(width: 28, height: 28)
                        .accessibilityHidden(true)
                    Image(nsImage: AppIdentity.icon(bundleID: place.window.bundleID))
                        .resizable().scaledToFit().frame(width: 28, height: 28).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.appName + " · " + place.regionName).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        Text(place.window.title.isEmpty ? place.appName : place.window.title)
                            .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityLabel("\(code.uppercased()): \(place.appName), \(place.regionName), \(place.window.title)")
                .help("Return to \(place.appName) · \(place.window.title) · \(place.regionName)")
            Button { model.removeStack(place.id) } label: {
                Image(systemName: "trash").font(.system(size: 14)).frame(width: 28, height: 32)
            }.buttonStyle(.plain)
                .accessibilityLabel("Remove \(place.appName), \(place.regionName) from stacks")
                .help("Remove saved place (⌘⌫). ⌘Z undoes removal while stacks are open.")
        }
        .padding(12)
        .background(Color(nsColor: NSColor(rgb: selected ? palette.surface : palette.background)), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: NSColor(rgb: selected ? palette.control : palette.text)).opacity(selected ? 1 : 0.16), lineWidth: 1))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct StackCode: NSViewRepresentable {
    let code: String, prefix: String
    let palette: ThemePalette
    func makeNSView(context: Context) -> StackCodeCanvas { StackCodeCanvas() }
    func updateNSView(_ view: StackCodeCanvas, context: Context) {
        view.code = code; view.prefix = prefix; view.palette = palette; view.needsDisplay = true
    }
}
private final class StackCodeCanvas: NSView {
    var code = "", prefix = ""
    var palette = ThemePalette(theme: .glitch, dark: true)
    override func draw(_ dirtyRect: NSRect) {
        let width = bounds.height * BlockLettering.aspectRatio(for: code)
        BlockLettering.draw(code, in: CGRect(x: (bounds.width - width) / 2, y: 0, width: width, height: bounds.height),
            accent: NSColor(rgb: palette.control), typed: NSColor(rgb: palette.typedControl), prefixLength: prefix.count,
            background: NSColor(rgb: palette.background))
    }
}
