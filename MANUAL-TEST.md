# First trial

These checks require an interactive Mac session and Accessibility permission.
They have not been performed by the build or unit tests.

- Open TextEdit with a document. Summon hints; activate an exposed toolbar control.
- In Safari and Chromium, compare hints on native toolbar controls and web links.
  Record missing controls; accessibility coverage can differ by browser.
- Summon normal hints: verify the focused window and menu bar have badges, without other windows.
- Use the same Control + Shift + Space shortcut. Open the Apple menu and
  verify new hints appear only inside its menu. Select About This Mac and verify
  hints move to the resulting window.
- Open a native popup button or dropdown using its hint. Verify the open list
  replaces the old hints; selecting an item must not label unrelated windows.
- In the Apple menu, each enabled row should have exactly one hint. Static text,
  keyboard shortcuts, and unopened submenus must not get separate hints.
- Dismiss only the hints with Escape while leaving a native app menu or a status
  app menu open. Invoke again: only that menu's visible rows should get hints.
- In Finder, use a desktop item's menu-opening hint. Its context menu should
  receive hints automatically. Escape and summon again while the menu remains
  open: the same menu should be captured, without desktop/background controls.
- Open a same-window menu or dialog through a hint (for example a web app's
  account menu). When exposed through Accessibility, it should receive hints
  without requiring a new macOS window. An ordinary button that opens nothing
  must not bring back hints over the whole background window.
- Leave a tooltip visible and invoke hints: it must not be mistaken for a menu.
- In a dense menu at large hint size, connectors must stay behind every badge's
  background and text.
- Switch a Ghostty tab by hint, then type normally. Hints must stay off until the
  next shortcut invocation. Close buttons and window traffic-light controls must
  never receive hints. Neither should Close/Quit/Minimize/Zoom menu commands.
- Choose System Settings from the Apple menu with Settings initially closed,
  then with its window already open behind Ghostty. In both cases hints should
  follow to Settings after it finishes opening, without any menu bar hints.
- While waiting for a slow window to open, press Escape, type, or click elsewhere.
  Verify the pending follow-up cannot later reappear over your work.
- Verify hints render above native dropdowns. Escape dismisses hints while leaving
  the opened surface alone; a new invocation starts fresh with window + menu bar.
- Enable menu bar extras. Try an ordinary third-party status item and Control Center.
  Verify its icons can be clicked and that Control Center's popover alone gets
  the next hints, without menu bar badges. Test a hidden-menu-bar toggle too.
- Place a window on each monitor, including one above or left of the main display.
  Verify outline placement and label visibility.
- Start a two-letter hint; test Backspace, invalid letters, and Escape.
- Test the hotkey while paused, while scanning, and while hints are visible.
- Verify Command-C and normal typing outside a hint session are unaffected.
- Move or close the target window while hints are visible. A stale control should
  fail cleanly. Switch apps/Spaces and confirm hints disappear.
- Add an app to the blacklist, then switch to an allowlist. Verify both modes,
  including menu bar owners; relaunch and confirm preferences persist.
- Revoke Accessibility access. Verify hints stop and settings show setup state.
- Note discovery latency, overlapping badges, missing controls, and accidental actions
  before spending time on animation, branding assets, configurable shortcuts,
  launch-at-login, and custom inline dropdown discovery.

- With HocusFocus enabled, open Control Center using hints, then move the pointer
  over another app without clicking. Verify hints remain and a two-letter selection
  still targets Control Center. Repeat while discovery is running and wait over
  15 seconds. Escape, a real click, scrolling, or the hotkey must still dismiss.
- After keeping hints through a focus change, close or move the target window
  manually before selecting: stale controls must not be activated.

- Open Tailscale's status menu: verify its embedded connection switch receives a
  hint separately from ordinary rows. Verify unopened submenus and decorative
  labels still receive no hints. Test the switch only when disconnecting is safe.

- In Now Playing, select a playback control, then invoke the shortcut again while
  the popup remains visible: only the media popup should receive hints, even when
  Chrome or Ghostty remains frontmost. Repeat after Escape.
- In Control Center, choose Wi-Fi and verify hints refresh when the same popup
  window changes content without changing its frame. Normal Settings toggles must
  not automatically restart hints.
- Open App Store: sidebar buttons and their nested cells must share one hint.
  Check diagnostics for rejected roles/actions and reachedLimit if content is missing.
- Maximize a window: badges must remain visible at one inner edge when no outside
  space exists. Smaller windows should use exterior rails and short connector stubs.

- Open two Ghostty windows: fresh invocation should show a gold two-letter selector
  at the top center of each visible title bar. Selecting the other window should
  focus and raise it, then stop capturing typing. Minimized windows and windows
  from other apps must not receive window selectors; popup-only sessions must not
  expose background window selectors. Ghostty update banners must have no hint.
- Type the first hint letter: teal badges should highlight it pink, pink badges
  yellow, and purple badges teal; the remaining code must retain its base color.

- At the largest hint size, crowd controls until local labels no longer fit.
  Verify a readable action panel appears, its footer explains paging, and Tab /
  Shift–Tab reach every action. Prefix filtering must preserve each code.
- In a crowded window's section view, check that section captions do not cover
  one another, ordinary hints, or detected text. With no clear gutter, verify
  section choices move into the action panel instead of overlapping.
