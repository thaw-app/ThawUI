#!/bin/sh
# Compiles Shaders/*.metal into the metallib that ThawUI ships, and records each source's SHA-256 so a
# test can catch a shader edited without rebuilding. Needs Xcode's Metal Toolchain:
#   xcodebuild -downloadComponent MetalToolchain
set -eu
air=""
cd "$(dirname "$0")/.."

out=Sources/ThawUI/Resources
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

for src in Shaders/*.metal; do
    name=$(basename "$src" .metal)
    xcrun -sdk macosx metal -c -target air64-apple-macos26.0 "$src" -o "$tmp/$name.air"
    air="$air $tmp/$name.air"
done
# shellcheck disable=SC2086
xcrun -sdk macosx metallib $air -o "$out/ThawUI.metallib"
shasum -a 256 Shaders/*.metal > Shaders/sources.sha256
echo "Wrote $out/ThawUI.metallib"
