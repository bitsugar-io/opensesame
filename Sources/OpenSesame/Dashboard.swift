import AppKit
import SwiftUI
import OpenSesameCore
import OpenSesameBrand

private let sizePresets = [(value: 12, name: "Compact"), (value: 16, name: "Default"), (value: 20, name: "Large")]
enum DashboardPage: String, CaseIterable { case hints = "Hints", stacks = "Stacks", letters = "Letters", apps = "Apps", style = "Style" }

final class DashboardDraft: ObservableObject {
    @Published var page: DashboardPage
    @Published var alphabet: String
    @Published var codePrefix: String
    @Published var length: Int
    @Published var error: String?
    init(configuration: HintConfiguration, page: DashboardPage) {
        self.page = page; alphabet = configuration.alphabet; codePrefix = configuration.prefix; length = configuration.minimumLength
    }
}
struct Dashboard: View {
    @Environment(\.colorScheme) private var colorScheme
    private var dark: Bool { model.appearanceMode.isDark(systemIsDark: colorScheme == .dark) }
    private var palette: ThemePalette { model.palette(dark: dark) }
    private var neon: Color { Color(nsColor: NSColor(rgb: palette.control)) }
    private var mint: Color { Color(nsColor: NSColor(rgb: palette.tab)) }
    @ObservedObject var model: Controller
    @StateObject private var draft: DashboardDraft
    init(model: Controller, page: DashboardPage = .hints) {
        self.model = model
        _draft = StateObject(wrappedValue: DashboardDraft(configuration: model.hintConfiguration, page: page))
    }
    var body: some View {
        VStack(spacing: 16) {
            header
            if !model.trusted { permissionNotice }
            ThemedSegments(selection: $draft.page, options: DashboardPage.allCases.map { ($0, $0.rawValue) }, palette: palette)
            Group {
                switch draft.page {
                case .hints: hintControls
                case .stacks: stackControls
                case .letters: letterControls
                case .apps: applicationControls
                case .style: styleControls
                }
            }
            .disabled(!model.configurationValid)
            HStack(spacing: 8) {
                Circle().fill(model.enabled && model.trusted ? mint : .secondary).frame(width: 5, height: 5)
                Text(model.message).font(.system(size: 10)).foregroundStyle(.secondary)
                    .lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.horizontal, 2)
            HStack {
                Button { model.editConfiguration() } label: { Label("TOML", systemImage: "curlybraces") }
                    .font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(.secondary)
                Button { model.reloadConfiguration() } label: { Image(systemName: "arrow.clockwise") }
                    .font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(.secondary)
                    .help("Reload TOML configuration").accessibilityLabel("Reload configuration")
                Spacer()
                Button { NSApp.terminate(nil) } label: { Label("Quit", systemImage: "power") }
                    .font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }.padding(20).frame(width: 400)
            .background(Color(nsColor: NSColor(rgb: palette.background)))
            .preferredColorScheme(model.appearanceMode == .system ? nil : model.appearanceMode == .dark ? .dark : .light)
            .foregroundStyle(Color(nsColor: NSColor(rgb: palette.text))).tint(neon)
            .onChange(of: model.hintConfiguration) { configuration in
                draft.alphabet = configuration.alphabet
                draft.codePrefix = configuration.prefix
                draft.length = configuration.minimumLength
                draft.error = nil
            }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 13) {
            Image(nsImage: BrandArtwork.logo(primary: NSColor(rgb: palette.control), secondary: NSColor(rgb: palette.tab), wordmark: NSColor(rgb: palette.text)))
                .resizable().interpolation(.high).scaledToFit().frame(width: 360, height: 61)
                .accessibilityLabel("OpenSesame")
            HStack {
                Text("LESS MOUSE. MORE MAYHEM.")
                    .font(.system(size: HintStyle.minimumTextSize, weight: .semibold, design: .monospaced)).tracking(1.2).foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(model.trusted && model.enabled && model.configurationValid ? neon : Color.secondary)
                        .frame(width: 5, height: 5)
                    Text(!model.configurationValid ? "CONFIG" : !model.trusted ? "SETUP" : model.enabled ? "LIVE" : "PAUSED")
                        .font(.system(size: HintStyle.minimumTextSize, weight: .bold, design: .monospaced))
                }
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(Color(nsColor: NSColor(rgb: palette.text)).opacity(0.05), in: Capsule())
            }
        }
    }
    private var permissionNotice: some View {
        Button { model.requestPermission() } label: {
            HStack(spacing: 10) {
                Image(systemName: "hand.raised.fill").font(.system(size: 18))
                VStack(alignment: .leading, spacing: 3) {
                    Text("One permission. A lot less mouse.").font(.system(size: 12, weight: .semibold))
                    Text("Open Accessibility settings to enable hints.").font(.system(size: 10))
                }
                Spacer(); Image(systemName: "arrow.up.right")
            }.foregroundStyle(neon).padding(12)
                .background(neon.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }
    private var hintControls: some View {
        let examples = Hints.labels(count: 3, configuration: model.hintConfiguration).map { $0.uppercased() }
        return VStack(alignment: .leading, spacing: 15) {
            Toggle(isOn: $model.enabled) {
                Label { Text("Keyboard hints") } icon: {
                    Image(nsImage: BrandArtwork.mark(size: 18, primary: NSColor(rgb: palette.control), secondary: NSColor(rgb: palette.tab)))
                        .frame(width: 18, height: 18)
                }.font(.system(size: 13, weight: .semibold))
            }.toggleStyle(.switch)
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Summon hints").font(.system(size: 12, weight: .medium))
                    Text("Release the keys. Type the label.").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                ShortcutRecorder(model: model).frame(width: 150, height: 30)
            }
            Text("WHILE HINTS ARE OPEN").font(.system(size: HintStyle.minimumTextSize, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
            HStack(spacing: 7) {
                key("Esc", "Dismiss"); key("⌫", "Edit / back"); key("⌘ ⇧ 3", "Screenshot")
            }
            Divider()
            HStack {
                Text("Hint size").font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(Int(model.hintSize)) pt").font(.system(size: 18, design: .monospaced)).foregroundStyle(mint)
            }
            HintSamples(samples: [(examples[0], palette.alternate, palette.typedAlternate),
                                  (examples[1], palette.tab, palette.typedTab),
                                  (examples[2], palette.control, palette.typedControl)],
                        fontSize: CGFloat(model.hintSize), background: palette.background)
            HintSizeSlider(value: $model.hintSize, presets: sizePresets.map(\.value),
                           markerColor: NSColor(rgb: palette.tab), accentColor: NSColor(rgb: palette.control), onCommit: {})
                .frame(height: 54)
            HStack(spacing: 7) {
                ForEach(sizePresets, id: \.value) { preset in
                    Button { model.hintSize = Double(preset.value) } label: {
                        VStack(spacing: 3) {
                            Text(preset.name).font(.system(size: 10, weight: .medium))
                            Text("\(preset.value) pt").font(.system(size: HintStyle.minimumTextSize, design: .monospaced))
                        }.frame(maxWidth: .infinity).padding(.vertical, 7)
                            .background(model.hintSize == Double(preset.value) ? mint.opacity(0.15) : Color(nsColor: NSColor(rgb: palette.text)).opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(model.hintSize == Double(preset.value) ? mint : Color.secondary)
                    }.buttonStyle(.plain)
                }
            }
            HStack(spacing: 14) {
                legend("Menus", color: Color(nsColor: NSColor(rgb: palette.alternate)))
                legend("Tabs", color: mint); legend("Controls", color: neon)
            }
            Text("WINDOWS AND SECTIONS").font(.system(size: HintStyle.minimumTextSize, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
            RegionHintSamples(codes: examples, palette: palette, fontSize: CGFloat(model.hintSize)).frame(maxWidth: .infinity)
            Divider()
            Toggle("Include menu bar extras", isOn: $model.includeMenuBar).font(.system(size: 11)).toggleStyle(.switch).controlSize(.mini)
            Text("Selecting a tab refreshes its controls; Backspace returns to tabs. Selecting a window returns to normal typing. Close and window-size controls are skipped.")
                .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.card(surface: Color(nsColor: NSColor(rgb: palette.surface)))
    }
    private var stackControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            section("STACKS", detail: "Return to a place without drilling down again.")
            HStack {
                Text("Show stacks").font(.system(size: 13, weight: .medium))
                Spacer()
                ShortcutRecorder(model: model, purpose: .stacks).frame(width: 150, height: 30)
            }
            HStack {
                Text("Save stack").font(.system(size: 13, weight: .medium))
                Spacer()
                ShortcutRecorder(model: model, purpose: .saveStack).frame(width: 150, height: 30)
            }
            Text("Click the shortcut to change it. This is separate from Summon hints.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Divider()
            HStack {
                Button("Show stacks") { model.showStacks() }
                Button("Resume last") { model.resumeLastStack() }
            }.disabled(!model.enabled || !model.trusted)
            Text("Save only places you choose. Open hints, drill to a section, then press Save stack. Up to five places stay in your TOML file until you remove them. Press 1–5 to return; ⌘⌫ removes a place and ⌘Z undoes removal.")
                .font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
            Text("WHILE HINTS ARE OPEN").font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                Text("\(model.saveStackShortcut.display) · Save this place")
                Text("Space · Show stacks")
                Text("Return · Resume last place")
                Text("Shift–Backspace · Previous place")
                Text("Backspace · Parent section / edit code")
            }.font(.system(size: 12))
            Divider()
            Text("Returning brings the window forward and refreshes its controls. It never presses a saved control. If the region changed, you get the window’s current choices.")
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.card(surface: Color(nsColor: NSColor(rgb: palette.surface)))
    }
    private var styleControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            section("APPEARANCE", detail: "Your palette. Light or dark.")
            ThemedSegments(selection: $model.appearanceMode, options: [(.system, "System"), (.light, "Light"), (.dark, "Dark")], palette: palette)
            Text("System follows your Mac’s appearance automatically.").font(.system(size: 10)).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    let colors = theme == .custom ? ((try? (dark ? model.customTheme.dark : model.customTheme.light).palette()) ?? ThemePalette(theme: .glitch, dark: dark)) : ThemePalette(theme: theme, dark: dark)
                    Button { model.theme = theme } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 5) {
                                ForEach([colors.control, colors.alternate, colors.tab, colors.window], id: \.self) { value in
                                    Circle().fill(Color(nsColor: NSColor(rgb: value))).frame(width: 12, height: 12)
                                }
                                Spacer()
                                if model.theme == theme { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
                            }
                            Text(theme.title).font(.system(size: 11, weight: .medium))
                        }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: NSColor(rgb: colors.background)), in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(Color(nsColor: NSColor(rgb: colors.text)))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(model.theme == theme ? mint : .secondary.opacity(0.2)))
                    }.buttonStyle(.plain)
                }
            }
            if model.theme == .custom {
                Divider()
                Text("Editing the \(dark ? "dark" : "light") variant. Switch appearance to edit the other.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                ForEach([("Background", \CustomTheme.Colors.background), ("Surface", \.surface), ("Text", \.text),
                         ("Controls", \.control), ("Menus", \.alternate), ("Tabs", \.tab), ("Desktop / regions", \.window)], id: \.0) { title, path in
                    ColorPicker(title, selection: customColor(path), supportsOpacity: false).font(.system(size: 11))
                }
                Text("Choose readable text and distinct hint colors. Custom variants are saved separately in TOML.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }.card(surface: Color(nsColor: NSColor(rgb: palette.surface)))
    }
    private func customColor(_ path: WritableKeyPath<CustomTheme.Colors, String>) -> Binding<Color> {
        Binding(get: {
            let colors = dark ? model.customTheme.dark : model.customTheme.light
            let value = UInt32(colors[keyPath: path].dropFirst(), radix: 16) ?? 0
            return Color(nsColor: NSColor(rgb: value))
        }, set: { color in
            var custom = model.customTheme
            if dark { custom.dark[keyPath: path] = NSColor(color).hexRGB }
            else { custom.light[keyPath: path] = NSColor(color).hexRGB }
            model.customTheme = custom
        })
    }
    private var letterControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            section("HINT LETTERS", detail: "Your keys. Your muscle memory.")
            Text("Minimum code length").font(.system(size: 12, weight: .medium))
            ThemedSegments(selection: $draft.length, options: [(1, "1 letter"), (2, "2 letters"), (3, "3 letters")], palette: palette)
            Text(draft.length == 1 ? "Quick, but one key can trigger an action. Codes grow when more targets need them." : "Every code has the same length. Codes grow automatically when needed.")
                .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            Text("Alphabet").font(.system(size: 12, weight: .medium))
            TextField("Hint letters", text: $draft.alphabet).font(.system(size: 12, design: .monospaced)).textFieldStyle(.roundedBorder)
                .accessibilityLabel("Hint alphabet")
            HStack(spacing: 7) {
                Button("Distinct letters") { draft.alphabet = HintConfiguration.defaultAlphabet }
                Button("Home row") { draft.alphabet = "asdfjkl" }
            }.font(.system(size: 10)).buttonStyle(.bordered)
            Text("Two or more unique letters. Their order determines the codes. Popup ledgers add left-to-right numbers (A1, A2).").font(.system(size: 10)).foregroundStyle(.secondary)
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Optional prefix").font(.system(size: 12, weight: .medium))
                    Text("Up to three extra letters before every code.").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                TextField("None", text: $draft.codePrefix).font(.system(size: 12, design: .monospaced)).frame(width: 60)
                    .textFieldStyle(.roundedBorder).accessibilityLabel("Hint prefix")
            }
            HintSamples(samples: sampleCodes.enumerated().map { index, code in
                let colors = HintStyle.colors(kind: .control, index: index, palette: palette)
                return (code.uppercased(), colors.accent, colors.typed)
            }, fontSize: CGFloat(model.hintSize), background: palette.background, prefixLength: 1)
                .padding(.vertical, 4)
            if let error = draft.error { Text(error).font(.system(size: 10)).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true) }
            HStack {
                Button("Reset") { draft.length = 2; draft.alphabet = HintConfiguration.defaultAlphabet; draft.codePrefix = ""; draft.error = nil }
                Spacer()
                Button("Apply letters", action: applyLetters).buttonStyle(.borderedProminent)
            }.font(.system(size: 11))
        }.card(surface: Color(nsColor: NSColor(rgb: palette.surface)))
    }
    private var applicationControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            section("APPLICATIONS", detail: "Choose where the magic works.")
            ThemedSegments(selection: $model.only, options: [(false, "Except these apps"), (true, "Only these apps")], palette: palette)
            ScrollView {
                VStack(spacing: 6) {
                    if model.apps.isEmpty {
                        Text(model.only ? "Add an app to enable hints." : "All apps are allowed.").font(.system(size: 11)).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 60)
                    }
                    ForEach(model.apps, id: \.self) { app in
                        HStack(spacing: 9) {
                            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 20, height: 20)
                                Text(url.deletingPathExtension().lastPathComponent).font(.system(size: 11)).help(app)
                            } else { Image(systemName: "macwindow").foregroundStyle(neon); Text(app).font(.system(size: 11)) }
                            Spacer()
                            Button { model.apps.removeAll { $0 == app } } label: { Image(systemName: "minus.circle.fill").foregroundStyle(.secondary) }
                                .buttonStyle(.plain).accessibilityLabel("Remove \(app)")
                        }.padding(.vertical, 4)
                    }
                }
            }.frame(height: min(max(CGFloat(model.apps.count) * 32, 70), 180))
            HStack {
                TextField("App name or bundle ID", text: $model.newApp).font(.system(size: 11)).textFieldStyle(.plain).onSubmit(addApp)
                Button(action: addApp) { Image(systemName: "plus") }.buttonStyle(.plain).accessibilityLabel("Add app")
                Menu {
                    ForEach(NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }, id: \.processIdentifier) { app in
                        if let id = app.bundleIdentifier { Button(app.localizedName ?? id) { add(id) } }
                    }
                } label: { Image(systemName: "chevron.down") }.menuStyle(.borderlessButton).frame(width: 20).help("Choose a running app")
            }.padding(10).background(Color(nsColor: NSColor(rgb: palette.background)), in: RoundedRectangle(cornerRadius: 7))
            Text("Filters also apply to the apps that own menu bar items.").font(.system(size: 10)).foregroundStyle(.secondary)
            Divider()
            Toggle("Website icons for Chrome", isOn: Binding(get: { model.chromeIcons }, set: { model.configureChromeIcons($0) }))
                .font(.system(size: 12))
            Text("Uses Chrome’s local icon cache and asks for Automation access. App icons remain the fallback.")
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if !model.iconAccessMessage.isEmpty {
                Text(model.iconAccessMessage).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
            }
        }.card(surface: Color(nsColor: NSColor(rgb: palette.surface)))
    }
    private var sampleCodes: [String] {
        guard let config = try? HintConfiguration(minimumLength: draft.length, alphabet: draft.alphabet, prefix: draft.codePrefix) else { return ["—"] }
        return Hints.labels(count: 3, configuration: config)
    }
    private func applyLetters() {
        do {
            try model.configureHints(length: draft.length, alphabet: draft.alphabet, prefix: draft.codePrefix)
            draft.alphabet = model.hintConfiguration.alphabet; draft.codePrefix = model.hintConfiguration.prefix
            draft.length = model.hintConfiguration.minimumLength
            draft.error = nil
        } catch { draft.error = error.localizedDescription }
    }
    private func section(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: HintStyle.minimumTextSize, weight: .semibold, design: .monospaced)).tracking(1.5)
            Text(detail).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }
    private func key(_ code: String, _ caption: String) -> some View {
        VStack(spacing: 4) {
            Text(code).font(.system(size: 16, weight: .semibold)).foregroundStyle(mint)
            Text(caption).font(.system(size: 11)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 9).background(Color(nsColor: NSColor(rgb: palette.background)), in: RoundedRectangle(cornerRadius: 7))
            .help(caption == "Screenshot" ? "Command + Shift + 3: take a screenshot without dismissing hints." : caption == "Dismiss" ? "Escape: dismiss hints." : "Backspace: remove the last hint letter.")
            .accessibilityLabel(caption == "Screenshot" ? "Screenshot: Command Shift 3" : caption == "Dismiss" ? "Dismiss: Escape" : "Edit code: Backspace")
    }
    private func legend(_ title: String, color: Color) -> some View {
        HStack(spacing: 4) { Circle().fill(color).frame(width: 4, height: 4); Text(title).font(.system(size: HintStyle.minimumTextSize)).foregroundStyle(.secondary) }
    }
    private func addApp() { add(model.newApp); model.newApp = "" }
    private func add(_ raw: String) {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty && !model.apps.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) { model.apps.append(value) }
    }
}
private extension View {
    func card(surface: Color) -> some View {
        padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.06)))
    }
}
