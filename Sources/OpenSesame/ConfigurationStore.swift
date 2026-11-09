import AppKit
import OpenSesameCore

extension Controller {
    var configurationURL: URL { configurationFileOverride ?? AppConfiguration.location() }
    func currentConfiguration() -> AppConfiguration {
        var config = AppConfiguration()
        config.theme = theme; config.appearance = appearanceMode; config.custom = customTheme; config.shortcut = shortcut; config.stacksShortcut = stacksShortcut
        config.saveStackShortcut = saveStackShortcut
        config.hints.size = hintSize; config.hints.menuBar = includeMenuBar
        config.hints.minimumLength = hintConfiguration.minimumLength
        config.hints.alphabet = hintConfiguration.alphabet; config.hints.prefix = hintConfiguration.prefix
        config.apps.mode = only ? .only : .except; config.apps.list = apps
        config.icons.chrome = chromeIcons
        if stacksConfigured { config.stacks = StacksConfiguration(places: stacks.ordered) }
        return config
    }
    func writeConfiguration(_ config: AppConfiguration) throws {
        let disk = FileManager.default.fileExists(atPath: configurationURL.path)
            ? try String(contentsOf: configurationURL, encoding: .utf8) : nil
        guard disk == loadedConfigurationSource else {
            throw ConfigurationError.invalid("TOML changed on disk. Reload before saving changes.")
        }
        let source = try config.toml()
        _ = try AppConfiguration.parse(source)
        try FileManager.default.createDirectory(at: configurationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try source.write(to: configurationURL, atomically: true, encoding: .utf8)
        loadedConfigurationSource = source
    }
    func persistStacks(_ updated: NavigationStacks, migrating: Bool = false) throws {
        guard configurationLoaded, configurationValid, !applyingConfiguration else {
            throw ConfigurationError.invalid("Reload a valid configuration before saving stacks.")
        }
        guard stacksConfigured || migrating else {
            throw ConfigurationError.invalid("Saved places could not be migrated. Repair the legacy stacks file, then reload TOML.")
        }
        var config = currentConfiguration()
        config.stacks = StacksConfiguration(places: updated.ordered)
        try writeConfiguration(config)
        stacksConfigured = true
        stackSaveError = nil
    }
    func saveConfiguration() {
        guard configurationLoaded, !applyingConfiguration, configurationValid else { return }
        do {
            try writeConfiguration(currentConfiguration())
        } catch {
            if let source = loadedConfigurationSource, let previous = try? AppConfiguration.parse(source) {
                try? applyConfiguration(previous)
            }
            configurationValid = false
            cancel(reason: "configuration-save-failed")
            message = "Could not save TOML: \(error.localizedDescription)"
        }
    }
    func reloadConfiguration() {
        do {
            let source = try String(contentsOf: configurationURL, encoding: .utf8)
            let config = try AppConfiguration.parse(source)
            try applyConfiguration(config)
            loadedConfigurationSource = source
            configurationValid = true
            message = "Configuration loaded. \(shortcut.display) to summon hints."
            stackSaveError = nil
            loadStacks()
        } catch {
            configurationValid = false
            cancel(reason: "invalid-configuration")
            message = "TOML: \(error.localizedDescription)"
        }
    }
    private func applyConfiguration(_ config: AppConfiguration) throws {
        applyingConfiguration = true
        defer { applyingConfiguration = false }
        try configureHints(length: config.hints.minimumLength, alphabet: config.hints.alphabet, prefix: config.hints.prefix)
        theme = config.theme; appearanceMode = config.appearance; customTheme = config.custom; shortcut = config.shortcut; stacksShortcut = config.stacksShortcut
        saveStackShortcut = config.saveStackShortcut
        hintSize = config.hints.size; includeMenuBar = config.hints.menuBar
        only = config.apps.mode == .only; apps = config.apps.list
        chromeIcons = config.icons.chrome
        stacksConfigured = config.stacks != nil
        stacks = NavigationStacks(places: config.stacks?.places ?? [])
        let kept = Set(stacks.places.map(\.id))
        liveStackWindows = liveStackWindows.filter { kept.contains($0.key) }
    }
    func loadConfigurationAtStartup() {
        configurationLoaded = true
        if FileManager.default.fileExists(atPath: configurationURL.path) { reloadConfiguration() }
        else { saveConfiguration() } // Migrate the existing menu preferences once.
        // Upgrade the former built-in alphabet; preserve intentional custom sets.
        if configurationValid, [HintConfiguration.legacyAlphabet, HintConfiguration.previousDefaultAlphabet].contains(hintConfiguration.alphabet) {
            try? configureHints(length: hintConfiguration.minimumLength, alphabet: HintConfiguration.defaultAlphabet, prefix: hintConfiguration.prefix)
        }
        loadStacks()
    }
    func editConfiguration() {
        if !FileManager.default.fileExists(atPath: configurationURL.path) { saveConfiguration() }
        NSWorkspace.shared.open(configurationURL)
    }
}
