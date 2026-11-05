# Agent instructions

- Use `fd`, `rg`, and `jaq` instead of `find`, `grep`, and `jq`.
- Never commit unless explicitly asked. Create a branch before committing;
  never commit directly to `main`. Pushing requires separate authorization.
- Read [CONTRIBUTING.md](CONTRIBUTING.md) for development and verification.
- Do not start, stop, or replace the running app without the user's instruction.
  Use an isolated SwiftPM scratch directory for checks while the app is in use.
- Keep input callbacks free of AppKit, Accessibility work, and UI waits.
- Report automated, rendered-preview, and live interaction checks separately.
