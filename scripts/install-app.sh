#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="xLyra Monitor.app"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/.build/app/$APP_NAME"
INSTALL_DIR="${1:-$HOME/Applications}"
ICON_NAME="XlyraMonitorIcon"
APP_VERSION="${APP_VERSION:-0.1.0}"

cd "$ROOT_DIR"
python3 scripts/generate-app-icon.py
iconutil -c icns "Resources/$ICON_NAME.iconset" -o "Resources/$ICON_NAME.icns"
swift build -c release --product XlyraMonitorApp

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/XlyraMonitorApp" "$APP_DIR/Contents/MacOS/XlyraMonitorApp"
cp "Resources/$ICON_NAME.icns" "$APP_DIR/Contents/Resources/$ICON_NAME.icns"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>XlyraMonitorApp</string>
    <key>CFBundleIdentifier</key>
    <string>com.xlyra.monitor</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>xLyra Monitor</string>
    <key>CFBundleIconFile</key>
    <string>XlyraMonitorIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2026</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_DIR"

mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/$APP_NAME"
cp -R "$APP_DIR" "$INSTALL_DIR/$APP_NAME"
echo "$INSTALL_DIR/$APP_NAME"
