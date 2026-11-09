#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

# Exercise the real run script with a fake builder and launcher. These tests
# must never compile, launch, stop, or register a real application.
fixture="$(mktemp -d "${TMPDIR:-/tmp}/opensesame-workflows.XXXXXX")"
fixture="${fixture:A}"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/scripts" "$fixture/bin"
cp scripts/run-app.sh "$fixture/scripts/run-app.sh"
cp scripts/reset-accessibility.sh "$fixture/scripts/reset-accessibility.sh"
cp justfile "$fixture/justfile"
cat > "$fixture/scripts/build-app.sh" <<'SH'
#!/bin/zsh
set -eu
print built >> "$OPENSESAME_TEST_BUILD_LOG"
if [[ "${OPENSESAME_TEST_BUILD_FAIL:-0}" == 1 ]]; then exit 99; fi
mkdir -p dist/OpenSesame.app/Contents/MacOS
touch dist/OpenSesame.app/Contents/MacOS/OpenSesame
chmod +x dist/OpenSesame.app/Contents/MacOS/OpenSesame
SH
mkdir -p "$fixture/dist/OpenSesame.app/Contents/MacOS"
cat > "$fixture/dist/OpenSesame.app/Contents/MacOS/OpenSesame" <<'RAW'
#!/bin/zsh
print -u2 'ERROR: raw executable launched without LaunchServices'
exit 99
RAW
chmod +x "$fixture/dist/OpenSesame.app/Contents/MacOS/OpenSesame"
cat > "$fixture/bin/pgrep" <<'SH'
#!/bin/zsh
exit 1
SH
cat > "$fixture/bin/open" <<'SH'
#!/bin/zsh
printf '%s\n' "$@" > "$OPENSESAME_TEST_LAUNCH_LOG"
SH
chmod +x "$fixture/bin/pgrep" "$fixture/bin/open"
export OPENSESAME_TEST_BUILD_LOG="$fixture/build.log"
export OPENSESAME_TEST_LAUNCH_LOG="$fixture/launch.log"
export PATH="$fixture/bin:$PATH"

# Bare just must only list recipes, without building or launching.
just --justfile "$fixture/justfile" > "$fixture/default.log"
[[ ! -e "$fixture/build.log" && ! -e "$fixture/launch.log" ]]
[[ "$(< "$fixture/default.log")" == *'Available recipes:'* ]]

just --justfile "$fixture/justfile" run
[[ ! -e "$fixture/build.log" ]]
launch_args=("${(@f)$(< "$fixture/launch.log")}")
[[ ${#launch_args} == 3 ]]
[[ "$launch_args[1]" == -g && "$launch_args[2]" == -n ]]
[[ "$launch_args[3]" == "$fixture/dist/OpenSesame.app" ]]

# An existing instance must be left alone, with no rebuild or second launch.
cat > "$fixture/bin/pgrep" <<'SH'
#!/bin/zsh
exit 0
SH
rm "$fixture/launch.log"
if zsh "$fixture/scripts/run-app.sh" > "$fixture/rejection.log" 2>&1; then
    print -u2 'Expected run to reject an already running instance.'
    exit 1
fi
[[ ! -e "$fixture/build.log" && ! -e "$fixture/launch.log" ]]

# Run must report a missing build without building or launching.
cat > "$fixture/bin/pgrep" <<'SH'
#!/bin/zsh
exit 1
SH
rm "$fixture/dist/OpenSesame.app/Contents/MacOS/OpenSesame"
if zsh "$fixture/scripts/run-app.sh" > "$fixture/missing.log" 2>&1; then
    print -u2 'Expected run to reject a missing build.'
    exit 1
fi
[[ ! -e "$fixture/build.log" && ! -e "$fixture/launch.log" ]]
[[ "$(< "$fixture/missing.log")" == *'just start'* ]]

# Start must build from a fresh checkout and then launch.
just --justfile "$fixture/justfile" start
[[ -e "$fixture/build.log" && -e "$fixture/launch.log" ]]
[[ "$(< "$fixture/build.log")" == built ]]

# Failed builds must never launch an old app.
rm "$fixture/build.log" "$fixture/launch.log"
if OPENSESAME_TEST_BUILD_FAIL=1 just --justfile "$fixture/justfile" start > "$fixture/failure.log" 2>&1; then
    print -u2 'Expected run to stop after a failed build.'
    exit 1
fi
[[ -e "$fixture/build.log" && ! -e "$fixture/launch.log" ]]
# Permission resets use fake native tools, never the user's real LS/TCC data.
export OPENSESAME_TEST_PERMISSION_LOG="$fixture/permission.log"
cat > "$fixture/bin/lsregister" <<'SH'
#!/bin/zsh
[[ "$1" == -f && "$2" == "$PWD/dist/OpenSesame.app" ]] || exit 98
print register >> "$OPENSESAME_TEST_PERMISSION_LOG"
if [[ "${TEST_REGISTER_FAIL:-0}" == 1 ]]; then exit 99; fi
SH
chmod +x "$fixture/bin/lsregister"
cat > "$fixture/bin/tccutil" <<'SH'
#!/bin/zsh
[[ "$*" == 'reset Accessibility io.bitsugar.opensesame' ]] || exit 98
print reset >> "$OPENSESAME_TEST_PERMISSION_LOG"
case "${TEST_RESET_MODE:-success}" in
    success) print 'Successfully reset Accessibility approval status' ;;
    missing) print -u2 'tccutil: No such bundle identifier "io.bitsugar.opensesame": (OSStatus error -10814.)'; exit 64 ;;
    failure) print -u2 'Permission reset failed'; exit 64 ;;
esac
SH
chmod +x "$fixture/bin/tccutil"
just --justfile "$fixture/justfile" clean > "$fixture/reset-success.log"
[[ "$(< "$OPENSESAME_TEST_PERMISSION_LOG")" == $'register\nreset' ]]
# Missing bundles still permit first-run cleanup, but an existing moved bundle
# must be registered first; a failed registration must stop before TCC reset.
mv "$fixture/dist/OpenSesame.app" "$fixture/unbuilt.app"
TEST_RESET_MODE=missing just --justfile "$fixture/justfile" clean > "$fixture/reset-missing.log"
[[ "$(< "$fixture/reset-missing.log")" == *'no Accessibility reset is needed'* ]]
mv "$fixture/unbuilt.app" "$fixture/dist/OpenSesame.app"
: > "$OPENSESAME_TEST_PERMISSION_LOG"
if TEST_REGISTER_FAIL=1 just --justfile "$fixture/justfile" clean > "$fixture/register-failure.log" 2>&1; then
    print -u2 'Expected clean to stop after native registration fails.'
    exit 1
fi
[[ "$(< "$OPENSESAME_TEST_PERMISSION_LOG")" == register ]]
if TEST_RESET_MODE=failure just --justfile "$fixture/justfile" clean > "$fixture/reset-failure.log" 2>&1; then
    print -u2 'Expected clean to preserve an unrelated reset failure.'
    exit 1
fi
[[ "$(< "$fixture/reset-failure.log")" == *'Permission reset failed'* ]]
print '4 Accessibility reset fixture checks passed (registration before reset, unbuilt app, registration failure, unrelated reset failure).'

print '6 workflow tests passed (default lists only, run without building, existing-instance protection, missing build, start builds and launches, and build failure).'
