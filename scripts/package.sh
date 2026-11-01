#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${VERSION:-1.1.0}"
ARCH="${ARCH:-$(uname -m)}"
case "$VERSION" in *[!0-9A-Za-z.-]*) echo "Invalid VERSION" >&2; exit 1;; esac
case "$ARCH" in arm64|x86_64) ;; *) echo "ARCH must be arm64 or x86_64" >&2; exit 1;; esac
if [[ "${CONFIGURATION:-release}" == debug ]]; then
  swift build -c debug --arch "$ARCH" -Xswiftc -gnone
else
  swift build -c release --arch "$ARCH"
fi
BIN_DIR="$(swift build -c "${CONFIGURATION:-release}" --arch "$ARCH" --show-bin-path)"
STAGING="$(mktemp -d "$PWD/.build/package.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/Promecapt.app"
mkdir -p dist
SPARKLE_FRAMEWORK=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
PUBLIC_UPDATE_KEY="$(tr -d '\n\r' < updates/public-key.txt)"
BUNDLE_ID=com.promlee.promepaste
FEED_URL="https://github.com/PROMLEE/promecapt/releases/latest/download/appcast-$ARCH.xml"
if [[ "${UPDATE_TESTING:-0}" == 1 ]]; then
  [[ "${CONFIGURATION:-release}" == debug ]] || { echo 'Updater fixtures require a debug build' >&2; exit 1; }
  BUNDLE_ID=com.promlee.promecapt.update-test
  FEED_URL="${TEST_UPDATE_FEED:?Loopback feed required}"
  PUBLIC_UPDATE_KEY="${TEST_UPDATE_PUBLIC_KEY:?Test public key required}"
fi
REVISION="$(git rev-parse --short HEAD)"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Promecapt" "$APP/Contents/MacOS/Promecapt"
cp LICENSE "$APP/Contents/Resources/LICENSE"
cp .build/checkouts/Sparkle/LICENSE "$APP/Contents/Resources/Sparkle-LICENSE"
mkdir -p "$APP/Contents/Frameworks"
ditto "$SPARKLE_FRAMEWORK" "$APP/Contents/Frameworks/Sparkle.framework"
install_name_tool -add_rpath @executable_path/../Frameworks "$APP/Contents/MacOS/Promecapt"
cp Sources/Promecapt/Resources/Translations.json "$APP/Contents/Resources/Translations.json"
mkdir -p .build/icon-module-cache
xcrun swiftc -module-cache-path .build/icon-module-cache Sources/Promecapt/CaptureMark.swift scripts/Icon.swift -o .build/PromecaptIcon
.build/PromecaptIcon .build/Promecapt.iconset
iconutil -c icns .build/Promecapt.iconset -o "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleName</key><string>Promecapt</string>
<key>CFBundleDisplayName</key><string>Promecapt</string>
<key>CFBundleExecutable</key><string>Promecapt</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>PromecaptRevision</key><string>$REVISION</string>
<key>SUFeedURL</key><string>$FEED_URL</string>
<key>SUPublicEDKey</key><string>$PUBLIC_UPDATE_KEY</string>
<key>SUEnableAutomaticChecks</key><false/>
<key>SUAutomaticallyUpdate</key><false/>
<key>SUScheduledCheckInterval</key><integer>86400</integer>
<key>SUVerifyUpdateBeforeExtraction</key><true/>
<key>SURequireSignedFeed</key><true/>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>ko</string><string>ja</string><string>zh-Hans</string></array>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>PromecaptApplication</string>
<key>NSScreenCaptureUsageDescription</key><string>선택한 화면을 캡처하여 편집하고 화면에 고정합니다.</string>
</dict></plist>
EOF
if [[ "${UPDATE_TESTING:-0}" == 1 ]]; then
  /usr/libexec/PlistBuddy -c 'Add :NSAppTransportSecurity dict' "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c 'Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true' "$APP/Contents/Info.plist"
fi
# Supply a Developer ID identity for distribution. Otherwise this is a local ad-hoc build.
if [[ "${SIGNING_IDENTITY:--}" == - ]]; then
  # Ad-hoc apps have no Developer Team shared with the upstream signed framework.
  # Limit the local-build Library Validation exception to this app; retain Hardened Runtime.
  codesign --force --options runtime --entitlements scripts/adhoc-entitlements.plist --sign - "$APP"
else
  framework="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
  for component in "$framework"/XPCServices/*.xpc "$framework/Autoupdate" "$framework/Updater.app"; do
    codesign --force --options runtime --sign "$SIGNING_IDENTITY" "$component"
  done
  codesign --force --options runtime --sign "$SIGNING_IDENTITY" "$APP/Contents/Frameworks/Sparkle.framework"
  codesign --force --options runtime --sign "$SIGNING_IDENTITY" "$APP"
fi
codesign --verify --deep --strict "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/Promecapt-$VERSION-macos-$ARCH.zip"
shasum -a 256 "dist/Promecapt-$VERSION-macos-$ARCH.zip" > "dist/Promecapt-$VERSION-macos-$ARCH.zip.sha256"
if [[ -e dist/Promecapt.app ]]; then mv dist/Promecapt.app "$STAGING/previous.app"; fi
if ! mv "$APP" dist/Promecapt.app; then
  if [[ -e "$STAGING/previous.app" ]]; then mv "$STAGING/previous.app" dist/Promecapt.app; fi
  exit 1
fi
echo "Created dist/Promecapt.app and dist/Promecapt-$VERSION-macos-$ARCH.zip"
