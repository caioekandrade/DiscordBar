#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DESTINATION="${1:-$PROJECT_DIR/build}"
mkdir -p "$DESTINATION/DiscordBar.app/Contents/MacOS" "$DESTINATION/DiscordBar.app/Contents/Resources"
xcrun swiftc -swift-version 5 -O -target "$(uname -m)-apple-macosx13.0" \
    -framework AppKit -framework ApplicationServices -framework ServiceManagement \
    "$PROJECT_DIR/Sources/main.swift" \
    -o "$DESTINATION/DiscordBar.app/Contents/MacOS/DiscordBar"
cp "$PROJECT_DIR/Info.plist" "$DESTINATION/DiscordBar.app/Contents/Info.plist"
codesign --force --sign - --identifier local.caio.discordbar "$DESTINATION/DiscordBar.app"
