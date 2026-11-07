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
The **Stacks** page records a separate shortcut, stored as `[stacks_shortcut]`.
Its default is Control–Option–Space. Hints and stacks bindings must differ.
Old TOML files inherit the stacks default when the table is absent. If their
hints binding already uses it, stacks defaults to Control–Option–Shift–Space.

Popup codes share a row letter, with enabled controls numbered left to right.
Numeric widths grow together so a short code cannot activate before a longer
one has been typed. The configured prefix applies to popup codes too. Sparse
windows keep direct hints; crowded windows offer at most three sections first.
Selecting a crowded section subdivides only that region, again into at most
three. Letter codes select sections and individual controls. Backspace edits
the code, then returns to the parent when the code is empty; Escape dismisses.
Controls that cannot be placed locally move into a readable action panel with
Tab / Shift+Tab paging. Prefix filtering preserves codes and resets the page.
Close and window-size controls are excluded. Window choices include other exposed,
accessible windows across allowed apps. The current window has controls or sections
instead of a redundant refocus code; its sibling windows remain selectable.
Tabs and controls come only from the current window. Windows, sections, tabs, and ordinary controls use the configured
alphabet, prefix, and code length. The default `sadfjkwt` is curated for both
the block glyphs and compact uppercase tags. Preserve the original artwork;
remove confusing letters from the default instead of changing their shapes.
Migrate only exact former built-in defaults and preserve custom alphabets.

## Navigation stacks

Stacks keep at most five explicitly saved places. Opening hints, using a
control, cancelling, and switching apps must never insert a place. Save the
current window or deepest selected section only through **Save stack** (default
Control–Option–Return) or the picker’s **Save** button. Opening the picker may
capture a current-place preview, but must not persist it without that action.
The save shortcut is configurable in Settings and `[save_stack_shortcut]`; it
only captures input during hints or the picker. All three shortcuts must differ.

Persist all saved places in `[stacks]` / `[[stacks.places]]` in `config.toml`.
Keep insertion order; updating or recalling a place must not move its slot.
Never evict an entry to make room: a sixth save explains that one must be removed.
Preserve existing entries when upgrading; only the user removes them. The legacy
`pinned` field stays compatible, but there is no automatic Recent list or
separate unpin operation in the UI.

The picker uses **1–5**, drawn on the existing block grid, as an explicit exception
to configured hint letters. Renumber surviving entries from 1 immediately after removal; undo restores
the previous order and numbers. Invalidate queued input before changing the mapping. Show each app's local icon. Arrows and Return also recall. Command–Backspace
removes the highlighted entry; Command–Z undoes the last removal while the picker
stays open, until another explicit save. Native Save/remove buttons provide the
same operations. Save failures retain the existing places and explain recovery.

`NavigationStacks` owns saved-place order, recall history, and semantic anchors.
`ConfigurationStore` writes settings and stacks atomically through the same
guarded writer. Refuse to overwrite externally changed or deleted configuration.
`StackStore` only reads legacy favorites for a one-time migration, leaving that
file unchanged. An explicit empty `[stacks]` prevents deleted pins from returning.
Failed migrations preserve both files and block stack saves until repaired and
reloaded. `StackWindowResolver` uses a live window reference
within a session, and unique window identifiers or exact titles after restart.
It must never replace a closed window with a same-named one silently.

Recall raises the window, scans fresh controls, and matches the section against
semantic identities and window-relative positions. It never replays an action.
Changed or ambiguous regions fall back to the fresh root choices. Backspace
retains real section parents; Shift–Backspace walks between destinations.
Keyboard routing remains a bounded state machine; all AX and panel work runs
outside the input callback. Cancellation invalidates pending recall work.
Mouse events within the picker reach its native buttons and scrolling; outside
clicks dismiss it. Ordinary hints retain their mouse-dismissal behavior.

Verify the explicit-save boundary, five-place limit, contiguous numeric indices after removal, removal/undo,
deduplication, config and storage round trips,
window identity ambiguity, moved/resized windows, changed hint alphabets,
stale regions, and input cancellation. Render the production picker in light
and dark appearances, with all five places, empty history, removal feedback,
a narrow panel, and an unavailable window.
Live window activation and cross-app recall require separate checks.

## Accessibility and signing

Launch the packaged app through the documented workflows. Its bundle registers
with macOS before the first Accessibility trust check and requests access using
Apple's native `AXIsProcessTrustedWithOptions` API, as HocusFocus does. The panel's permission
button retries registration and opens Settings. Development builds are ad-hoc
signed; changed code can require approval again. The packaged app includes its
MIT license and dependency notices. Signing identity and license changes are
part of the packaging cache check. Set
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

The reset registers an existing bundle's current path before resetting its
approval, including after a checkout move. Native registration failure stops
the reset rather than reporting that no reset is needed. Approve access again
after the reset. Reopen System Settings if its app icon is
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
.github/                      CI, repository settings, and contribution automation
```

## Code standards

Keep macOS Accessibility calls in the app target. Core behavior must be testable
without controlling windows. Share theme colors and artwork through the existing
targets. Menu bar artwork must remain legible at small sizes.
Before traversing an app or popup provider, request `AXEnhancedUserInterface`
only if it advertises a disabled, writable value. Some renderers otherwise expose
only an empty container. Retry asynchronously while the tree becomes available;
never enable VoiceOver or alter macOS privacy permissions as a discovery fallback.

The blocking keyboard callback runs on a dedicated input thread. It must never
call AppKit, perform Accessibility work, draw, or wait for UI dispatch. Mouse
dismissal uses a separate listen-only tap. If the UI heartbeat is older than
750 ms, keystrokes pass through and capture disarms. Disabled taps stay disabled
until the app reopens. Input-source translation is cached on the main thread.

Keep app identity consistent across metadata, signing, notifications, and
permission resets. Report action failures accurately, preserve external TOML
edits, and avoid pixel-click fallbacks for ordinary controls.

### Shared Accessibility implementation

| Responsibility | Owner |
| --- | --- |
| Enable advertised, writable enhanced UI support | `AccessibilityPreparation` |
| Traverse visible menus and container navigation children | `AccessibilityTraversal` |
| Choose primary actions and writable disclosure state | `AccessibilityActionPolicy`, `AccessibilityActions` |
| Exclude window chrome and passive targets | `TargetExclusion`, `WebTargetPolicy` |
| Verify window focus and refresh after selection | `WindowSelection`, `Controller` |
| Select tabs/groups and retain a tab-choice parent | `TabSelection`, `SectionNavigation` |
| Preserve semantic colors and place overflow by source | `HintStyle`, `HintCanvas`, `LedgerPage` |

A menu's `AXVisibleChildren`, including an empty list, is authoritative. Other
known containers first use `AXChildren`, then navigation-order children or
`AXContents` when empty. Do not probe alternate trees on passive leaves. A
read-only `AXExpanded` must not hide a writable `AXDisclosing` on the same node.
Selection waits observe transitions; they do not replay an action after timeout.

Remaining compatibility exceptions are deliberately narrow: Spotify's legacy
manual/enhanced Accessibility preparation; Finder desktop-surface identity;
Control Center popup-provider matching; Ghostty's update-notice exclusion;
validated primary clicks for menu extras and tab-group headers; and Chrome's
optional local icon metadata adapter. These do not select app-specific layouts.
This is shared semantic handling, not a universal or self-learning AX interpreter.
When adding an exception, retain the live role/action/ancestry evidence and a
provider-independent regression fixture, and list the exception here.

## UX and layout contract

Apply these rules to every application, window, popup, theme, and generated
example. A layout change must update its shared policy and regression fixture;
do not add a second renderer or an app-specific visual workaround.

### Guiding principles

- **One interaction language across apps.** Use the same placement, sizing,
  colors, typography, and navigation rules for the same target kinds. An app's
  identity can inform discovery compatibility and supply its name/icon; it
  must not choose a different layout. Audit shared behavior when fixing an app.
- **Start with Accessibility semantics.** Discover the current window and
  exposed desktop surfaces, then classify roles, supported actions, enabled
  state, and writable disclosure state through `AccessibilityActionPolicy`.
  Prefer the advertised primary press/open action. Expand/collapse a group
  through its writable `AXExpanded` or `AXDisclosing` state when available;
  never substitute an edit/context menu. Keep close, minimize, maximize, and
  quit exclusions in the shared policy. Inspect missing controls before adding
  compatibility code; do not guess behavior from names, hint codes, or an app's
  identity. Record a narrow exception's evidence and failure reason.
- **Refresh the affected choices.** Window selection focuses the exact window
  and scans it automatically. Tab selection refreshes contents and keeps
  a tab-choice parent; group disclosure refreshes the changed surface. Desktop
  actions refresh exposed items when focus remains with the source or Finder.
  Menu-bar expansion refreshes the menu bar even without a new popup. Revalidate
  owner, enabled state, bounds, and cancellation before acting; never retry an
  action merely because AX timed out. A return code or a fixture is not proof
  that the user's intended transition occurred.
- **Keep choices predictable.** Every discovered eligible action must stay
  reachable. Preserve codes, placement, and colors while typing. Keep current
  window tabs at the window level. Section pages contain only their members;
  Backspace restores tabs and other choices from the actual parent. Preserve actual
  parents for Backspace; Escape always leaves the current interaction.
- **Show only useful levels.** Sparse content stays direct. Complex content
  offers at most three sections per level, with no empty or redundant one-box
  drill-down. Sections describe logical panes through their full bounds.
- **Use hierarchy consistently.** Large regions use the original block artwork
  and strong borders. Small tags use the shared compact font and light border.
  Color identifies a target's kind; shade variation must not imply a new kind.
- **Make overflow predictable and identifiable.** Place the panel outside its
  owning window or popup, right first and left only if the right cannot fit a
  readable column. Place it inside, near relevant content, only when neither
  side fits. App icon/name and descriptive row titles identify the source.
  Icons supplement text and codes. Do not invent favicons, fetch icons from the
  network, or require screen recording to decorate hints; use local app icons
  when a target-specific image is unavailable.
  Never mix owners in one overflow page. Group by process owner, keeping Desktop
  separate even from Finder windows. Show the active app's pages first; Tab and
  Shift+Tab cycle through every page and source. Each source uses its own bounds
  and heading. Show one panel at a time to avoid competing lists. Resolve local
  collisions against every source's unfiltered panel before typing so codes do
  not jump when the visible page changes. Membership, icons, and source labels
  remain stable while typing. Put the owner in the heading once; tab/window/object
  rows prefer their title and allow two lines at the configured readable size. The optional Chrome
  icon adapter supplies metadata only, never activation or placement behavior.
  It is disabled by default, requests Automation only on an explicit settings
  action, reads authoritative tab URLs for a uniquely matched non-incognito
  window, and rejects ambiguous titles. Read exact URLs from a temporary,
  read-only snapshot of Chrome's checkpointed local icon cache. Delete that
  snapshot afterward; never persist tab URLs, read history to guess them, or
  download icons. New cache entries may be unavailable until Chrome checkpoints.
- **Keep frequent actions on the keyboard.** Save, recall, remove, undo,
  and navigation need visible keyboard paths. Provide feedback where the action
  happens. Recalling a place reveals fresh choices; it never replays an action.
- **Keep this contract current.** Every UI behavior change must update the
  relevant rule here, its shared implementation, and a regression fixture in
  the same change. Resolve conflicts explicitly instead of adding a local
  exception. Review actual light/dark renders, and distinguish automated,
  rendered-preview, and live interaction evidence.

Use Apple's [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
and [Typography](https://developer.apple.com/design/human-interface-guidelines/typography)
guidance for Mac readability. The placement distances and lanes below are
OpenSesame design choices; they need rendered and live usability checks.

### Placement and reachability

- Use target kind, Accessibility role, control geometry, and available space.
  Toolbars and generic `AXShowMenu` actions on group/tab-group containers are
  not individual controls. Traverse their children and preserve real tab,
  button, and `AXPress` group actions. Apply this policy to every app.
  App identity may inform discovery compatibility, but must not select visual
  placement, font size, or badge styling.
  A tab-group header inside a tab strip is a tab choice, including when its
  only advertised action opens a group menu. Never use that edit menu as primary
  selection. Prefer its native press/open action; when absent, primary-click an
  exposed tab-group header only after checking its live role, parent, owner,
  bounds, and Accessibility hit target. A coarse hit result is acceptable only
  for a real AXGroup/AXTabGroup/AXToolbar ancestor owned by the same process,
  containing the entire header, and belonging to the same AXWindow. An unrelated
  same-app element is not sufficient. This is a target-role exception, not an
  app-specific layout or a general click fallback. A generic tab container is
  not a selectable header. Prefer an advertised
  primary press/open action over a context menu; never discard a usable `AXOpen`.
- Individual controls prefer an upper-left annotation with a 6-point gap.
  If blocked, try centered above, centered below, then the left gutter. Check
  text, controls, other badges, and the display's 4-point safety inset. Vertical
  toolbars prefer two repeating left-side lanes so their end buttons stay
  aligned with the group. Never cover an ordinary control's glyph to keep its
  hint local.
- Compact horizontal groups use one aligned strip, preserving left-to-right
  order. Prefer below, then above; when both are blocked, use a captioned strip
  outside the popup only within 48 points of every associated control. Individual
  exterior captions obey the same maximum gap; never search arbitrarily far
  across or below a window for room. Use the shared overflow panel when that
  association cannot be kept. This geometry-based exception keeps dense duration and
  media controls together rather than staggering each label independently.
- Only `AXMenuBarItem` targets use the downward menu-bar lanes. A toolbar near
  the top of a display is still a toolbar. Open menu rows use the action panel.
  All menu-bar items use compact tags and direct leaders, with no extra target
  rectangle. Missing Accessibility names must not change their border treatment.
  When a menu-bar action rearranges icons without opening a popup, refresh the
  menu bar after it settles. Do not substitute background window controls for
  an absent popup, or leave the overlay empty after a successful expansion.
- Tab hints stay inside their tab, using space around measured title and control
  frames. Preserve the configured glyph size; if a complete hint cannot fit,
  use the action panel. Never move a tab hint above its tab. Current-window tabs
  remain direct choices at the window level, outside section membership.
  A section shows only its own controls; Backspace restores its parent's choices,
  including tabs at the window level. Crowded content must not force a fitting
  tab hint into the action panel at that level.
  Selecting a group refreshes tab choices; selecting a tab refreshes its contents.
  The fresh tab list is the parent of those contents, so Backspace returns to
  tabs after any nested sections. Do not dismiss hints after selecting a tab.
- Windows and sections use large block codes centered inside matching colored
  borders, without location or count captions. For a partly covered window,
  place its code in the largest exposed area that can hold it. Clip the border
  to exposed window areas. Omit the selector for the current window whose controls
  are being navigated, so its code cannot compete with a section code.
  Background windows remain selectable; their tabs
  and controls are outside the current window's session. Selecting a window
  activates it once, waits asynchronously for that exact window to gain focus,
  and scans its controls automatically. Preserve the intended activation across
  app-change notifications, but invalidate pending work on cancellation. Verify
  owner and focused window again before displaying results. This applies to every
  app, including terminals; selecting a window never requires a second hotkey.
  On fresh hints, include exposed desktop items even when Finder is not active.
  Identify the desktop by Finder's desktop-icon WindowServer surface, not its
  localized title. Subtract normal application windows from desktop icon bounds and obey app
  filters. Include partially exposed icons; fully covered icons remain hidden.
  Put their compact tags inside an exposed thumbnail corner (top-right first),
  using the same font, 1-point outline and 4-point inset as inline object labels.
  Do not draw a leader or extra target outline. If no exposed corner can hold
  the full code, keep the named choice on a separate Desktop overflow page. Keep desktop
  choices outside window section grouping.
  A desktop stack/group gets its own compact corner tag when Accessibility
  exposes a primary action or writable disclosure state. Use that provider's
  advertised open/press action or writable state to expand/collapse it; file tags
  keep their Open action. Finder's Screenshots stack currently advertises AXOpen
  with no writable disclosure state, so it must not require a synthetic toggle.
  Do not whitelist only images/buttons/cells or assume an English title such as "Screenshots".
  Open popups remain scoped to their own controls.
  Dismiss old selectors when another app activates. A pending action follow-up
  or stack recall may finish its own transition; a completed popup scan must
  not leave old labels over a newly activated app. Cancellation invalidates
  queued scan results as well as hiding the overlay.
  If an exposed strip cannot hold a complete code, the action panel identifies
  the window by title. A crowded control panel must preserve other windows'
  spatial selectors wherever they fit.
  Compute window occlusion from normal application windows. WindowServer's
  surface alpha does not prove that a system overlay's pixels are opaque;
  screen-sized notification canvases must not hide all window choices.
- Crowded-window sections split at empty corridors between whole controls,
  preferring wider gaps over equal action counts. Show at most three regions
  per level, with no connectors between regions. The initial threshold is 40
  controls; after entry, subdivide groups above 18 where clean splits exist.
  Borders follow the logical pane edges through the full window, not the outermost
  detected controls. Child panes inherit their parent's bounds with an 8-point gutter.
  Keep overlapping controls together; if a crowded group cannot split, use
  the paged action panel. Sparse windows and popups retain direct hints.
  Backspace with an empty code restores the parent choices, positions, and
  colors. Centered block codes may overlay section contents while choosing a
  region; individual control hints preserve their underlying glyphs and text.
- Place in screen-local AppKit coordinates after converting Accessibility's
  desktop coordinates once. Respect offset displays and screen edges.
- Resolve collisions before prefix filtering. Typing must preserve each
  surviving code, badge position, and accent. Draw orthogonal connectors behind
  badges using the same 3-point stroke as region borders; never draw a line over
  a code. Windows, sections, inline tabs, and desktop thumbnails have no connectors. Aligned strips map in reading order;
  detached annotations need captions. Unnamed controls retain a connector and
  target outline, except menu-bar items whose dedicated lanes already identify
  the target. An empty or generic caption cannot identify other unnamed actions.
- Reserve the full badge and caption footprint. Keep successful local hints;
  send unplaced hints to the paged action panel. Keep its unfiltered footprint
  and membership stable while typing; hide it when no overflow entries match. Every action must remain
  reachable. Never silently drop actions or reduce text size to fit more hints.
  Anchor the panel to the complete owning window, even while navigating a child
  section; scoped popups use their own bounds. Prefer the right exterior side,
  then left, then an interior fallback when both sides lack room. Use one
  readable column with paging; extra room must not expand it into a different
  multi-column layout. Collision
  avoidance can slide an exterior panel vertically along that side, but cannot
  move it over the window or switch sides merely to avoid a badge. Relocate any
  covered hints into the same panel. Interior fallback favors the active region
  and minimizes collisions. Keep this policy in `LedgerPage`, shared by every app.

### Visual language and assets

- [HintStyle.swift](Sources/OpenSesameCore/HintStyle.swift) owns badge padding,
  corner radius, and border weights. Compact control, menu, and tab tags use a
  1-point outline without a halo; action panels and detached strips use a
  neutral 1-point outline. Windows, sections, target outlines, and connectors keep
  the stronger 3-point stroke. [HintBorder.swift](Sources/OpenSesameBrand/HintBorder.swift)
  draws the canvas borders; settings samples use the same stroke metrics.
  Its color mapping preserves target semantics in local hints and overflow:
  menus use the palette's `alternate` accent, tabs use `tab`, and controls use
  `control`. Desktop items use the `window` accent (gold in the default theme)
  as their own semantic family; spatial window/section choices still use the
  region cycle below. Adjacent tags vary only in shade within their family. The shade
  uses the target's unfiltered ordinal within its family and stays fixed while
  typing. Typed characters retain their distinct progress color.
  [HintTypography.swift](Sources/OpenSesameBrand/HintTypography.swift) supplies
  SF Mono Semibold for compact codes at the configured hint size (10–22 points).
  Local tags, overflow codes, measurement, and settings samples share this font.
  The original large block lettering remains unchanged.
  Captions use at least 12 points; compact panel headings
  and metadata use at least 10 points.
- [Theme.swift](Sources/OpenSesameCore/Theme.swift) and the selected custom
  palette own UI colors. Preserve control, menu, tab, region, and typed-code
  meanings across appearances. Settings samples must use the same badge metrics
  and colors as live hints. Appearance changes must not change placement.
  Keep the existing TOML `alternate` key for compatibility; its settings label
  is now **Menus**. Custom palettes retain their configured colors.
- Windows and sections cycle through distinct theme accents in spatial order.
  Each border, block code, and overflow code shares its region's color, which
  stays fixed while typing. Unique letter codes identify regions when colors repeat.
  Use a 3-point outline with a contrasting 5-point halo and no interior fill.
- Settings pages share `Dashboard` cards, section headings, `ThemedSegments`,
  native focus behavior, and labeled controls. Hint samples stack when full
  codes cannot fit in a row; do not shrink, truncate, or clip codes. Reuse those components instead
  of introducing page-specific navigation or competing spacing systems.
- [BrandArtwork.swift](Sources/OpenSesameBrand/BrandArtwork.swift) owns the portal
  mark and wordmark for the menu bar, settings, icon, and README. Generate assets
  through that target; do not hand-edit generated images. Template menu-bar art
  follows macOS appearance; app icons and promotional art may retain brand colors.
- [BlockLettering.swift](Sources/OpenSesameBrand/BlockLettering.swift) reuses the
  wordmark's seven original glyphs directly and extends its four-row block grid
  to all A–Z letters and the stack indices 1–5. Windows, sections, stacks, and their settings samples share this
  vector renderer. Do not replace it with an installed or imported font.
- Render examples with the actual views and hint canvas. Label synthetic
  examples and live captures explicitly. Never use a mock badge renderer as
  evidence that the production layout works.

### Layout change verification

Exercise local controls, horizontal strips, vertical toolbars, short/wide tabs,
menu bars, menu rows, window selectors, sections, and mixed local/overflow hints.
Include small/default/large hints, light/dark appearances, blocked gutters,
screen edges, unnamed controls, longest configured codes, and prefix filtering
in mixed local/overflow layouts. Test geometry in Core and render the actual
canvas for visual changes. Provider-neutral browser/native/terminal fixtures
must give identical placement for identical geometry. Inspect rendered images
at readable scale; action reachability alone does not prove clarity.

Report automated checks, rendered previews, and live interaction separately.
Cross-app live validation remains outstanding until performed with the user's
running app. Do not start, stop, or replace it to complete this checklist.

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
changed bundle while OpenSesame is running. Verify live interactions separately;
automated results do not prove cross-app behavior.

### Artwork and rendered examples

```sh
just artwork
just previews /private/tmp/opensesame-checks
```

Artwork comes from the native brand target. Development-only rendering lives in
`DevelopmentPreviews.swift`; release builds exclude the synthetic fixtures and
reject `--render-previews`. Previews render native settings and
the actual hint canvas without starting the controller, installing input taps,
or changing the running app. They include local controls, horizontal duration
strips, browser-style tabs and vertical toolbars, menus, and
crowded-section/overflow pagination. The renderer checks every
overflow page for reachability and verifies prefix filtering. Preview failures
exit with an error instead of generating a crash report.
The `layout-sections-*` fixtures exercise unequal panels and successive
drill-down levels through the actual grouping policy and canvas at 10, 16,
and 22 points in both appearances. `hint-appearance-*` renders menu, tab, and
control color families alongside a large window marker at all three sizes.
It verifies that filtering and overflow preserve each tag's family and shade.
`layout-window-selection-*` exercises exposed
windows across apps, a transparent system overlay, a partly covered background
window, and inline tabs without a redundant selector for the current window.
`layout-player-*` replays sanitized Spotify control geometry through three regions,
two subregions, and the individual Play hint; its content is synthetic and does
not test live playback. `block-lettering-*` shows every glyph beside the original
wordmark. Inspect both light and dark renders.
`overflow-owner-*` keeps browser titles and Desktop items on separate source
pages in both appearances; `overflow-{right,left,inside}-*` verifies shared
placement for browser and terminal providers. `desktop-stack-*` renders
expanded/collapsed synthetic groups and individual
file tags through the same corner-placement policy in both appearances.

The README labels live captures separately from synthetic examples. Crop live
captures to the relevant UI and exclude private app content; keep full desktop
originals outside the repository. Rendered examples use synthetic controls.
The `detail-*.png` files are readable crops of the full layout renders. Keep
captions explicit about which images are rendered examples versus live captures.

### Live diagnostics

Focus the app to inspect, then ask the running OpenSesame process to show or hide
its overlays without synthetic keystrokes:

```sh
dist/OpenSesame.app/Contents/MacOS/OpenSesame --show-hints
dist/OpenSesame.app/Contents/MacOS/OpenSesame --hide-hints
dist/OpenSesame.app/Contents/MacOS/OpenSesame --diagnostics
dist/OpenSesame.app/Contents/MacOS/OpenSesame --inspect-ax com.google.Chrome
```

Diagnostics report the running source fingerprint, permission/hook state,
discovered targets, and the last eight discovery snapshots. Labels may contain
private app content; inspect output before sharing it. The app keeps this
history in memory and does not write logs to disk automatically. `--inspect-ax`
is a bounded, read-only tree inspection through the trusted running app; it does
not activate apps, perform actions, or change permissions. Keep raw dumps outside
version control and redact private titles before sharing.

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

## GitHub automation

[.github/](.github) follows HocusFocus's workflow set: Swift tests, Markdown and
justfile lint, Conventional Commits, dependency review/updates, pull request
labels, first-interaction greetings, stale handling, and tagged releases.
[repos.json](.github/repos.json) describes the desired OpenSesame repository
settings; [labeler.yml](.github/labeler.yml) maps this project's paths to labels.
The branch-deletion config matches the sibling project too. These files do not
apply repository settings or install a GitHub App by themselves. GitHub-side
configuration and workflow results must be verified separately.

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
