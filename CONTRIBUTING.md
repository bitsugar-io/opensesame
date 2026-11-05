# Contributing

Thanks for contributing to OpenSesame.

## Before you start

- Read the [Code of Conduct](CODE_OF_CONDUCT.md) and [AI policy](AI_POLICY.md).
- Keep existing TOML files compatible and changes focused.
- Describe what you actually verified; compilation does not prove Accessibility works.

## Development setup

Start with the [quickstart](README.md#quickstart) for requirements and first run.
Optional development tools are in [.mise.toml](.mise.toml):

```sh
mise trust
mise install
```

Swift comes from the selected Apple toolchain. [Package.swift](Package.swift)
defines targets and dependencies; `Package.resolved` pins dependency versions.
Bun runs Markdown linting and git-cliff generates release notes.

Run `just` to list commands; it never builds or launches anything. `just build`
builds only, `just run` launches the existing bundle, and `just start` builds then
launches. Stop a running app before replacing its bundle. Unchanged builds keep
their existing signature. Do not start or stop someone else's app to run checks.

## Configuration

The panel's **TOML** button opens `~/.config/opensesame/config.toml`. An absolute
`XDG_CONFIG_HOME` overrides `~/.config`; Finder-launched apps usually do not
inherit your shell environment. See [config.example.toml](config.example.toml)
and the [parser](Sources/OpenSesameCore/AppConfiguration.swift) for defaults and
validation. Check the example without launching the app:

```sh
just check-config /private/tmp/opensesame-checks
```

Panel edits save to that file. After external edits, reload before saving from
the panel; it refuses to overwrite changes it has not loaded. Invalid files
pause hints until repaired and reloaded. Choose themes on **Style**. Custom
palettes are saved as `[custom.light]` and `[custom.dark]`; the pickers edit the
variant currently displayed. Click the shortcut field on **Hints**, then press
a combination containing Command, Control, or Option. Escape cancels recording.

Popup codes share a row letter, with enabled controls numbered left to right.
Numeric widths grow together so a short code cannot activate before a longer
one has been typed. The configured prefix applies to popup codes too. Sparse
windows keep direct hints; crowded windows offer sections first. Local-placement
failure switches to a readable action panel with Tab / Shift+Tab paging. Prefix
filtering preserves codes and resets the page. Close and window-size controls
are excluded.

## Accessibility and signing

Launch the packaged app through the documented workflows. Its bundle registers
with macOS before requesting Accessibility permission. The panel's permission
button retries registration and opens Settings. Development builds are ad-hoc
signed; changed code can require approval again. Set
`OPENSESAME_SIGNING_IDENTITY` to use an installed signing certificate. Building
does not create certificates or change the keychain.

After source changes:

```sh
just stop start
```

To reset only OpenSesame's Accessibility approval, keeping preferences and build:

```sh
just stop clean start
```

Approve access again after the reset. Reopen System Settings if its app icon is
stale. Use a consistent installation path when granting permission.

## Project structure

```text
Package.swift                 Swift Package Manager targets and dependencies
Sources/OpenSesameCore/        configuration, input routing, and layout policies
Sources/OpenSesameBrand/       shared native vector artwork
Sources/OpenSesame/            menu bar app, Accessibility, overlays, and previews
Sources/BrandAssets/           generated README and app icon artwork
Tests/                        Swift Testing suites
Resources/                    app metadata, icon, and third-party license notices
scripts/                      packaging, launch, stop, and workflow checks
asset/                        generated README artwork and rendered examples
config.example.toml           example configuration
.github/                      CI, dependency updates, and contribution template
```

## Code standards

Keep macOS Accessibility calls in the app target. Core behavior must be testable
without controlling windows. Share theme colors and artwork through the existing
targets. Menu bar artwork must remain legible at small sizes.

The blocking keyboard callback runs on a dedicated input thread. It must never
call AppKit, perform Accessibility work, draw, or wait for UI dispatch. Mouse
dismissal uses a separate listen-only tap. If the UI heartbeat is older than
750 ms, keystrokes pass through and capture disarms. Disabled taps stay disabled
until the app reopens. Input-source translation is cached on the main thread.

Keep app identity consistent across metadata, signing, notifications, and
permission resets. Report action failures accurately, preserve external TOML
edits, and avoid pixel-click fallbacks for ordinary controls.

## Testing

```sh
just ready
```

This runs justfile formatting, Markdown lint, workflow/package fixtures, Swift
Testing suites, and release-note checks. To isolate Swift builds while someone
uses the app:

```sh
just test /private/tmp/opensesame-checks
```

Tests must not register login items, prompt for permissions, post input events,
or move focus. Package checks use fake tools. Release-note checks create commits
and tags only inside a disposable fixture. `just build` refuses to replace a
changed bundle while OpenSesame is running. Use [MANUAL-TEST.md](MANUAL-TEST.md)
for the live interaction gate; automated results do not prove cross-app behavior.

### Artwork and rendered examples

```sh
just artwork
just previews /private/tmp/opensesame-checks
```

Artwork comes from the native brand target. Previews render native settings and
the actual hint canvas without starting the controller, installing input taps,
or changing the running app. They include local controls, horizontal duration
strips, menus, and crowded-section/overflow pagination. The renderer checks every
overflow page for reachability and verifies prefix filtering. Preview failures
exit with an error instead of generating a crash report.

README examples use synthetic controls; do not substitute private app content.
The `detail-*.png` files are readable crops of the full layout renders. Keep
captions explicit about which images are rendered examples versus live captures.

### Live diagnostics

Focus the app to inspect, then ask the running OpenSesame process to show or hide
its overlays without synthetic keystrokes:

```sh
dist/OpenSesame.app/Contents/MacOS/OpenSesame --show-hints
dist/OpenSesame.app/Contents/MacOS/OpenSesame --hide-hints
dist/OpenSesame.app/Contents/MacOS/OpenSesame --diagnostics
```

Diagnostics report the running source fingerprint, permission/hook state,
discovered targets, and the last eight discovery snapshots. Labels may contain
private app content; inspect output before sharing it. The app keeps this
history in memory and does not write logs to disk automatically.

## Branching and contributions

Create a branch before committing. Never commit directly to `main`. Agents must
not commit unless explicitly asked; pushing requires separate instruction.
Use [Conventional Commits](https://conventionalcommits.org), for example:

```text
fix(hints): ignore passive notification windows
feat(theme): add a color preset
```

Describe the problem, resulting behavior, and validation in pull requests. Keep
rendered-preview results and live interaction checks separate. Follow
[AI_POLICY.md](AI_POLICY.md) for AI assistance.

## Releases

Main and pull request CI test the source without publishing downloads. A
`vMAJOR.MINOR.PATCH` tag triggers the [release workflow](.github/workflows/release.yml).
It tests and packages the optimized app for the runner's architecture, includes
the MIT and dependency licenses, and creates a GitHub Release with generated
notes. These builds are ad-hoc signed and not notarized.

[cliff.toml](cliff.toml) defines the Conventional Commit groups. Use
`just release-notes` to preview unreleased notes and `just test-release-notes` to
check grouping and tag boundaries in a temporary fixture. There is no separate
changelog. Tagging or publishing requires explicit maintainer authorization;
adding workflow files does not publish anything.
