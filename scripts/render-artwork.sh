#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swift build --product BrandAssets --disable-sandbox --cache-path "$PWD/.build/cache"
binary_dir="$(swift build --show-bin-path --disable-sandbox --cache-path "$PWD/.build/cache")"
"$binary_dir/BrandAssets" "$PWD"
iconutil --convert icns --output "$PWD/Resources/OpenSesame.icns" "$PWD/.build/branding/OpenSesame.iconset"
