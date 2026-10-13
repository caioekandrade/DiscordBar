#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="${1:-$PROJECT_DIR/build/DiscordBar.app}"
DMG_PATH="${2:-$PROJECT_DIR/dist/DiscordBar-1.0.dmg}"
if [ ! -f "$APP_PATH/Contents/MacOS/DiscordBar" ]; then
    echo "Aplicativo não encontrado. Execute bash build.sh primeiro." >&2
    exit 1
fi
mkdir -p "$(dirname "$DMG_PATH")"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp/}discordbar-dmg.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
ditto "$APP_PATH" "$STAGING_DIR/DiscordBar.app"
ln -s /Applications "$STAGING_DIR/Applications"
cp "$PROJECT_DIR/README.txt" "$STAGING_DIR/Leia-me.txt"
hdiutil create -volname DiscordBar -srcfolder "$STAGING_DIR" \
    -format UDZO -ov "$DMG_PATH"
