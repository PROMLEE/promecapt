#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="${APP_PATH:-dist/Promecapt.app}"
if [[ ! -d "$APP/Contents" ]]; then
  echo 'Build the app with bash scripts/package.sh first, or set APP_PATH.' >&2
  exit 1
fi
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
ARCH="$(lipo -archs "$APP/Contents/MacOS/Promecapt")"
case "$VERSION" in ''|*[!0-9A-Za-z.-]*) echo 'Invalid app version' >&2; exit 1;; esac
case "$ARCH" in arm64|x86_64) ;; *) echo 'Expected one supported architecture' >&2; exit 1;; esac
codesign --verify --strict "$APP"
# Keep packaging-only Python dependencies out of the global environment and app.
VENV=.build/dmg-venv
if [[ ! -x "$VENV/bin/python" ]]; then python3 -m venv "$VENV"; fi
"$VENV/bin/python" -m pip install --disable-pip-version-check -r scripts/dmg-requirements.txt
mkdir -p dist
DMG="dist/Promecapt-$VERSION-macos-$ARCH.dmg"
"$VENV/bin/python" -m dmgbuild -s scripts/dmg-settings.py -D "app=$APP" Promecapt "$DMG"
hdiutil verify "$DMG"
MOUNT="$(mktemp -d "$PWD/.build/dmg-verify.XXXXXX")"
cleanup() {
  hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
  rmdir "$MOUNT" 2>/dev/null || true
}
trap cleanup EXIT
hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT" "$DMG" >/dev/null
codesign --verify --deep --strict "$MOUNT/Promecapt.app"
[[ "$(readlink "$MOUNT/Applications")" == /Applications ]]
diff -qr "$APP" "$MOUNT/Promecapt.app"
cleanup
trap - EXIT
(cd dist && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
echo "Created $DMG (drag Promecapt to Applications)"
