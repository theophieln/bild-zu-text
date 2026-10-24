#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Bild zu Text.app"
CONTENTS="$APP/Contents"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" build/module-cache

xcrun swiftc -swift-version 6 -O \
    -target "$(uname -m)-apple-macosx13.0" \
    -module-cache-path "$PWD/build/module-cache" \
    -framework Cocoa -framework Vision \
    src/OCR.swift src/main.swift -o "$CONTENTS/MacOS/BildZuText"

cp src/Info.plist "$CONTENTS/Info.plist"
cp src/AppIcon.icns "$CONTENTS/Resources/AppIcon.icns"
plutil -lint "$CONTENTS/Info.plist"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
printf 'App: %s/%s\n' "$PWD" "$APP"
