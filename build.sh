#!/bin/bash
set -e
cd "$(dirname "$0")"

APP="Bild zu Text.app"
CONTENTS="$APP/Contents"

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"
cp src/Info.plist "$CONTENTS/Info.plist"
cp src/AppIcon.icns "$CONTENTS/Resources/AppIcon.icns"

swiftc -O \
    -framework Cocoa \
    -framework Vision \
    src/main.swift \
    -o "$CONTENTS/MacOS/BildZuText"

codesign --force --deep --sign - "$APP" 2>/dev/null || true

echo "Fertig: $(pwd)/$APP"
