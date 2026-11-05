#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

# Check the real packager in isolation: no compilation, real app, or signing.
fixture="$(mktemp -d "${TMPDIR:-/tmp}/opensesame-package.XXXXXX")"
fixture="${fixture:A}"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/scripts" "$fixture/Resources" "$fixture/Sources/Example" "$fixture/bin" "$fixture/.build/fake-bin"
cp scripts/build-app.sh "$fixture/scripts/build-app.sh"
cp Resources/Info.plist "$fixture/Resources/Info.plist"
cp Resources/OpenSesame.icns "$fixture/Resources/OpenSesame.icns"
print '// fixture' > "$fixture/Sources/Example/main.swift"
print '// fixture manifest' > "$fixture/Package.swift"
print 'binary' > "$fixture/.build/fake-bin/OpenSesame"
chmod +x "$fixture/.build/fake-bin/OpenSesame"
cat > "$fixture/bin/swift" <<'SH'
#!/bin/zsh
if [[ " $* " == *' --show-bin-path '* ]]; then print "$PWD/.build/fake-bin"; fi
SH
cat > "$fixture/bin/pgrep" <<'SH'
#!/bin/zsh
exit "${OPENSESAME_TEST_PROCESS_STATE:-1}"
SH
cat > "$fixture/bin/codesign" <<'SH'
#!/bin/zsh
if [[ " $* " == *' --force '* ]]; then print signed >> "$OPENSESAME_TEST_SIGN_LOG"; fi
SH
chmod +x "$fixture/bin/"*
export OPENSESAME_TEST_SIGN_LOG="$fixture/sign.log"
export PATH="$fixture/bin:$PATH"
app="$fixture/dist/OpenSesame.app"

zsh "$fixture/scripts/build-app.sh" > "$fixture/build.log"
fingerprint="$(/usr/libexec/PlistBuddy -c 'Print :OpenSesameBuildFingerprint' "$app/Contents/Info.plist")"
cmp -s Resources/OpenSesame.icns "$app/Contents/Resources/OpenSesame.icns"
[[ ${#fingerprint} == 12 && "$fingerprint" != *[^0-9a-f]* ]]
[[ "$(< "$fixture/sign.log")" == signed ]]

# A rebuild with identical inputs must preserve the signed bundle.
zsh "$fixture/scripts/build-app.sh" > "$fixture/unchanged.log"
[[ "$(< "$fixture/sign.log")" == signed ]]
[[ "$(< "$fixture/unchanged.log")" == *'Build unchanged'* ]]

# A changed source stamp must identify the new source and sign once more.
print '// changed' >> "$fixture/Sources/Example/main.swift"
zsh "$fixture/scripts/build-app.sh" > "$fixture/changed.log"
new_fingerprint="$(/usr/libexec/PlistBuddy -c 'Print :OpenSesameBuildFingerprint' "$app/Contents/Info.plist")"
[[ "$new_fingerprint" != "$fingerprint" ]]
[[ "$(wc -l < "$fixture/sign.log" | tr -d ' ')" == 2 ]]

# A running app must not be overwritten with a changed build.
cp "$app/Contents/Info.plist" "$fixture/before.plist"
print '// another change' >> "$fixture/Sources/Example/main.swift"
if OPENSESAME_TEST_PROCESS_STATE=0 zsh "$fixture/scripts/build-app.sh" > "$fixture/running.log" 2>&1; then
    print -u2 'Expected packaging to reject a running app.'
    exit 1
fi
cmp -s "$fixture/before.plist" "$app/Contents/Info.plist"
[[ "$(wc -l < "$fixture/sign.log" | tr -d ' ')" == 2 ]]
print '4 packaging checks passed (source stamp, unchanged signature, changed source, running-app protection).'
