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
cp LICENSE "$fixture/LICENSE"
cp -R Resources/Notices "$fixture/Resources/Notices"
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
cmp -s LICENSE "$app/Contents/Resources/LICENSE"
cmp -s Resources/Notices/TOMLDecoder-LICENSE.txt "$app/Contents/Resources/Notices/TOMLDecoder-LICENSE.txt"
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
# A certificate change must not preserve an old signature or overwrite a live app.
if OPENSESAME_TEST_PROCESS_STATE=0 OPENSESAME_SIGNING_IDENTITY=fixture-certificate zsh "$fixture/scripts/build-app.sh" > "$fixture/signing-running.log" 2>&1; then
    print -u2 'Expected a new signing identity to be rejected while app is running.'
    exit 1
fi
cmp -s "$fixture/before.plist" "$app/Contents/Info.plist"
OPENSESAME_SIGNING_IDENTITY=fixture-certificate zsh "$fixture/scripts/build-app.sh" > "$fixture/new-identity.log"
[[ "$(wc -l < "$fixture/sign.log" | tr -d ' ')" == 3 ]]
OPENSESAME_SIGNING_IDENTITY=fixture-certificate zsh "$fixture/scripts/build-app.sh" > "$fixture/same-identity.log"
[[ "$(wc -l < "$fixture/sign.log" | tr -d ' ')" == 3 ]]
print 'notice change' >> "$fixture/Resources/Notices/TOMLDecoder-LICENSE.txt"
OPENSESAME_SIGNING_IDENTITY=fixture-certificate zsh "$fixture/scripts/build-app.sh" > "$fixture/notice-change.log"
cmp -s "$fixture/Resources/Notices/TOMLDecoder-LICENSE.txt" "$app/Contents/Resources/Notices/TOMLDecoder-LICENSE.txt"
[[ "$(wc -l < "$fixture/sign.log" | tr -d ' ')" == 4 ]]
print '7 packaging checks passed (source stamp, unchanged signature, changed source, running-app protection, bundled licenses, signing identity, notice changes).'
