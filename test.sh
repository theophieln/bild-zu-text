#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build/module-cache
xcrun swiftc -swift-version 6 -warnings-as-errors -parse-as-library \
    -target "$(uname -m)-apple-macosx13.0" \
    -module-cache-path "$PWD/build/module-cache" \
    -framework Cocoa -framework Vision \
    src/OCR.swift Tests/Tests.swift -o build/Tests
build/Tests "$@"
