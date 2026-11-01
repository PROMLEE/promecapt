#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${VERSION:-1.0.0}"
ARCH="${ARCH:-$(uname -m)}"
case "$VERSION" in *[!0-9A-Za-z.-]*) echo "Invalid VERSION" >&2; exit 1;; esac
case "$ARCH" in arm64|x86_64) ;; *) echo "ARCH must be arm64 or x86_64" >&2; exit 1;; esac
swift build -c release --arch "$ARCH"
BIN_DIR="$(swift build -c release --arch "$ARCH" --show-bin-path)"
APP="dist/Promecapt.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Promecapt" "$APP/Contents/MacOS/Promecapt"
cp LICENSE "$APP/Contents/Resources/LICENSE"
cp Sources/Promecapt/Resources/Translations.json "$APP/Contents/Resources/Translations.json"
mkdir -p .build/icon-module-cache
xcrun swiftc -module-cache-path .build/icon-module-cache Sources/Promecapt/CaptureMark.swift scripts/Icon.swift -o .build/PromecaptIcon
.build/PromecaptIcon .build/Promecapt.iconset
iconutil -c icns .build/Promecapt.iconset -o "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.promlee.promepaste</string>
<key>CFBundleName</key><string>Promecapt</string>
<key>CFBundleDisplayName</key><string>Promecapt</string>
<key>CFBundleExecutable</key><string>Promecapt</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>ko</string><string>ja</string><string>zh-Hans</string></array>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>PromecaptApplication</string>
<key>NSScreenCaptureUsageDescription</key><string>선택한 화면을 캡처하여 편집하고 화면에 고정합니다.</string>
</dict></plist>
EOF
# Supply a Developer ID identity for distribution. Otherwise this is a local ad-hoc build.
codesign --force --options runtime --sign "${SIGNING_IDENTITY:--}" "$APP"
codesign --verify --strict "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/Promecapt-$VERSION-macos-$ARCH.zip"
shasum -a 256 "dist/Promecapt-$VERSION-macos-$ARCH.zip" > "dist/Promecapt-$VERSION-macos-$ARCH.zip.sha256"
echo "Created $APP and dist/Promecapt-$VERSION-macos-$ARCH.zip"
