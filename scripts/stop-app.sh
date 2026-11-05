#!/bin/zsh
set -euo pipefail

# Both executable names, for this user only. No compiler or packaged CLI needed.
app_pattern='^(OpenSesame)$'
app_user="$(id -u)"
if ! pgrep -u "$app_user" -x "$app_pattern" >/dev/null; then
    print 'OpenSesame is already stopped.'
    exit 0
fi
pkill -TERM -u "$app_user" -x "$app_pattern"
for attempt in {1..60}; do
    if ! pgrep -u "$app_user" -x "$app_pattern" >/dev/null; then
        print 'OpenSesame stopped.'
        exit 0
    fi
    sleep 0.05
done
print -u2 'OpenSesame has not stopped after 3 seconds.'
exit 1
