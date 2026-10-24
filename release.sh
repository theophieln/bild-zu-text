#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
./test.sh
./build.sh

STAGING_DIR="$(mktemp -d "$PWD/build/dmg.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
ditto "build/Bild zu Text.app" "$STAGING_DIR/Bild zu Text.app"
ln -s /Applications "$STAGING_DIR/Applications"
mkdir -p dist
hdiutil create -volname "Bild zu Text" -srcfolder "$STAGING_DIR" \
    -format UDZO -ov dist/Bild-zu-Text.dmg
hdiutil verify dist/Bild-zu-Text.dmg
printf 'DMG: %s/dist/Bild-zu-Text.dmg\n' "$PWD"
