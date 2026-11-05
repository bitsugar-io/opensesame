import AppKit
import OpenSesameCore

extension Controller {
    var configurationURL: URL { configurationFileOverride ?? AppConfiguration.location() }
    func currentConfiguration() -> AppConfiguration {
        var config = AppConfiguration()
        config.theme = theme; config.appearance = appearanceMode; config.custom = customTheme; config.shortcut = shortcut
        config.hints.size = hintSize; config.hints.menuBar = includeMenuBar
        config.hints.minimumLength = hintConfiguration.minimumLength
        config.hints.alphabet = hintConfiguration.alphabet; config.hints.prefix = hintConfiguration.prefix
        config.apps.mode = only ? .only : .except; config.apps.list = apps
        return config
    }
    func saveConfiguration() {
        guard configurationLoaded, !applyingConfiguration, configurationValid else { return }
        do {
            if FileManager.default.fileExists(atPath: configurationURL.path) {
                let disk = try String(contentsOf: configurationURL, encoding: .utf8)
                guard disk == loadedConfigurationSource else {
                    throw ConfigurationError.invalid("TOML changed on disk. Reload before saving panel changes.")
                }
            }
            let source = try currentConfiguration().toml()
            _ = try AppConfiguration.parse(source)
            try FileManager.default.createDirectory(at: configurationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try source.write(to: configurationURL, atomically: true, encoding: .utf8)
            loadedConfigurationSource = source
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
        theme = config.theme; appearanceMode = config.appearance; customTheme = config.custom; shortcut = config.shortcut
        hintSize = config.hints.size; includeMenuBar = config.hints.menuBar
        only = config.apps.mode == .only; apps = config.apps.list
    }
    func loadConfigurationAtStartup() {
        configurationLoaded = true
        if FileManager.default.fileExists(atPath: configurationURL.path) { reloadConfiguration() }
        else { saveConfiguration() } // Migrate the existing menu preferences once.
        // Upgrade the former built-in alphabet; preserve intentional custom sets.
        if configurationValid, hintConfiguration.alphabet == HintConfiguration.legacyAlphabet {
            try? configureHints(length: hintConfiguration.minimumLength, alphabet: HintConfiguration.defaultAlphabet, prefix: hintConfiguration.prefix)
        }
    }
    func editConfiguration() {
        if !FileManager.default.fileExists(atPath: configurationURL.path) { saveConfiguration() }
        NSWorkspace.shared.open(configurationURL)
    }
}
