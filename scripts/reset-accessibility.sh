#!/bin/zsh
set -euo pipefail

cd "${0:A:h:h}"
app_dir="$PWD/dist/OpenSesame.app"
# A moved checkout may leave TCC pointing at the old bundle while Launch
# Services no longer resolves its identifier. Register the current bundle
# before resetting this app's approval, otherwise tccutil skips stale records.
if [[ -d "$app_dir" ]]; then
    registration_tool="$(command -v lsregister || true)"
    registration_tool="${registration_tool:-/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister}"
    "$registration_tool" -f "$app_dir"
fi

# With no built bundle, a first-run reset can legitimately have nothing to do.
if output="$(tccutil reset Accessibility io.bitsugar.opensesame 2>&1)"; then
    print -r -- "$output"
else
    reset_status=$?
    if [[ ! -d "$app_dir" && "$reset_status" == 64 && "$output" == *'No such bundle identifier "io.bitsugar.opensesame"'* && "$output" == *'OSStatus error -10814'* ]]; then
        print 'OpenSesame is not registered with macOS; no Accessibility reset is needed. Use just start to build and launch it.'
    else
        print -ru2 -- "$output"
        exit "$reset_status"
    fi
fi
