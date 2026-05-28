#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="xLyra Monitor.app"
VERSION="${APP_VERSION:-0.1.3}"
APP_DIR="$ROOT_DIR/.build/app/$APP_NAME"
STAGE_DIR="$ROOT_DIR/.build/dmg/xLyra Monitor"
DIST_DIR="$ROOT_DIR/.build/dist"
DMG_PATH="$DIST_DIR/xLyra-Monitor-$VERSION.dmg"

cd "$ROOT_DIR"

scripts/install-app.sh "$ROOT_DIR/.build/install"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR" "$DIST_DIR"

cp -R "$APP_DIR" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "xLyra Monitor" \
    -srcfolder "$STAGE_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo "$DMG_PATH"
