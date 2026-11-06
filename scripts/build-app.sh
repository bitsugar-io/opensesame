#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-module-cache"
build_configuration="${OPENSESAME_BUILD_CONFIGURATION:-debug}"
if [[ "$build_configuration" != debug && "$build_configuration" != release ]]; then
    print -u2 'OPENSESAME_BUILD_CONFIGURATION must be debug or release.'
    exit 2
fi
signing_identity="${OPENSESAME_SIGNING_IDENTITY:--}"
swift build -c "$build_configuration" --disable-sandbox --cache-path "$PWD/.build/cache"
binary_dir="$(swift build -c "$build_configuration" --show-bin-path --disable-sandbox --cache-path "$PWD/.build/cache")"
app_dir="$PWD/dist/OpenSesame.app"
# Stamp source identity into the bundle so diagnostics identify the running code.
source_files=(Sources/**/*.swift(.N) Package.swift Resources/Info.plist Resources/OpenSesame.icns)
build_fingerprint="$(shasum -a 256 "${source_files[@]}" | shasum -a 256 | cut -c1-12)"
staged_plist="$PWD/.build/OpenSesame-Info.plist"
cp Resources/Info.plist "$staged_plist"
/usr/libexec/PlistBuddy -c "Add :OpenSesameBuildFingerprint string $build_fingerprint" "$staged_plist"
# Identity and bundled notices affect packaging even when Swift output is equal.
package_inputs="$(mktemp "$PWD/.build/package-inputs.XXXXXX")"
trap 'rm -f "$package_inputs"' EXIT
{
    print -r -- "$signing_identity"
    print -r -- "$build_configuration"
    shasum -a 256 "$binary_dir/OpenSesame" "$staged_plist" Resources/OpenSesame.icns LICENSE Resources/Notices/*
} > "$package_inputs"
package_stamp="$PWD/.build/opensesame-packaged-inputs.sha256"
# Preserve an unchanged signed bundle and its Accessibility identity.
if [[ -x "$app_dir/Contents/MacOS/OpenSesame" && -f "$package_stamp" ]] &&
    cmp -s "$package_inputs" "$package_stamp" &&
    cmp -s "$binary_dir/OpenSesame" "$app_dir/Contents/MacOS/OpenSesame" &&
    cmp -s "$staged_plist" "$app_dir/Contents/Info.plist" &&
    cmp -s Resources/OpenSesame.icns "$app_dir/Contents/Resources/OpenSesame.icns" &&
    codesign --verify --strict "$app_dir" >/dev/null 2>&1; then
    print "Build unchanged; keeping the signed app at $app_dir"
    exit 0
fi
if pgrep -u "$(id -u)" -x OpenSesame >/dev/null; then
    print -u2 'The app changed but OpenSesame is running. Run just stop before rebuilding.'
    exit 1
fi
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp Resources/OpenSesame.icns "$app_dir/Contents/Resources/OpenSesame.icns"
cp "$binary_dir/OpenSesame" "$app_dir/Contents/MacOS/OpenSesame"
cp "$staged_plist" "$app_dir/Contents/Info.plist"
cp LICENSE "$app_dir/Contents/Resources/LICENSE"
mkdir -p "$app_dir/Contents/Resources/Notices"
cp Resources/Notices/* "$app_dir/Contents/Resources/Notices/"
codesign --force --sign "$signing_identity" --identifier io.bitsugar.opensesame "$app_dir"
mv "$package_inputs" "$package_stamp"
print "Built $app_dir"
