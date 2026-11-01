#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SPARKLE_ED_PRIVATE_KEY:?Set the private Sparkle signing key in the release environment}"
umask 077
KEY_FILE="$(mktemp "${RUNNER_TEMP:-$PWD/.build}/promecapt-signing.XXXXXX")"
trap 'rm -f "$KEY_FILE"' EXIT
printf '%s\n' "$SPARKLE_ED_PRIVATE_KEY" > "$KEY_FILE"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' dist/Promecapt.app/Contents/Info.plist)"
ARCH="$(lipo -archs dist/Promecapt.app/Contents/MacOS/Promecapt)"
python3 scripts/generate-appcast.py --version "$VERSION" --arch "$ARCH" --key-file "$KEY_FILE"
