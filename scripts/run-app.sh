#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

if pgrep -u "$(id -u)" -x '^(OpenSesame)$' >/dev/null; then
    print -u2 'OpenSesame is already running. Use just stop before starting another instance.'
    exit 1
fi

if [[ ! -x "$PWD/dist/OpenSesame.app/Contents/MacOS/OpenSesame" ]]; then
    print -u2 'OpenSesame has not been built. Use just start to build and launch, or just build to build only.'
    exit 1
fi

# LaunchServices must create the process. Executing Contents/MacOS directly
# leaves the terminal as TCC's responsible app, even inside a valid app bundle.
# -g launches in the background; -n requests this build. Return immediately.
exec open -g -n "$PWD/dist/OpenSesame.app"
