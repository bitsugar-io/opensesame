set shell := ["zsh", "-eu", "-c"]

export CLANG_MODULE_CACHE_PATH := justfile_directory() / ".build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE := justfile_directory() / ".build/swift-module-cache"

default:
    @just --list

# Build the standalone menu bar app into dist/.
build:
    zsh scripts/build-app.sh

# Run workflow checks and hint-label and app-filter tests.
test scratch_path=(justfile_directory() / ".build"):
    zsh scripts/test-workflows.sh
    zsh scripts/test-package.sh
    swift test --disable-xctest --disable-sandbox --cache-path "{{ justfile_directory() }}/.build/cache" --scratch-path "{{ scratch_path }}"

# Launch the existing app in the background without building.
run:
    zsh scripts/run-app.sh

# Build the standalone app, then start it in the background.
start: build
    zsh scripts/run-app.sh

# Quit the running menu bar app.
stop:
    zsh scripts/stop-app.sh

# Reset only OpenSesame's Accessibility authorization; keep the build intact.
clean:
    zsh scripts/reset-accessibility.sh

# Format the justfile.
just-fmt:
    just --unstable --fmt

# Check the justfile's formatting.
just-fmt-check:
    just --unstable --fmt --check

# Run the local checks without launching the app.
ready: just-fmt-check md-lint test

# Regenerate the shared logo and application icon.
artwork:
    zsh scripts/render-artwork.sh

# Render UI checks into the scratch directory without launching the app.
previews scratch_path=(justfile_directory() / ".build"):
    swift build --product OpenSesame --disable-sandbox --cache-path "{{ justfile_directory() }}/.build/cache" --scratch-path "{{ scratch_path }}"
    "$(swift build --show-bin-path --disable-sandbox --cache-path .build/cache --scratch-path '{{ scratch_path }}')/OpenSesame" --render-previews "{{ scratch_path }}/previews"

# Check the bundled TOML example without starting the app.
check-config scratch_path=(justfile_directory() / ".build"):
    swift test --disable-xctest --disable-sandbox --cache-path "{{ justfile_directory() }}/.build/cache" --scratch-path "{{ scratch_path }}" --filter bundledExampleConfiguration

# Check Markdown with the same version as HocusFocus and CI.
md-lint:
    bunx --bun markdownlint-cli2@0.24.0 '**/*.md'

# Preview notes since the last release; writes nothing.
release-notes:
    git-cliff --config cliff.toml --unreleased --strip header
