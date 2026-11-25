#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Redragon Olaf RGB.app"
APP_DIR="$ROOT_DIR/$APP_NAME"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES_DIR="$CONTENTS/Resources"

echo "==> Building $APP_NAME..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

# 1. Generate AppIcon.icns
ICONSET="$ROOT_DIR/.build_iconset/AppIcon.iconset"
rm -rf "$ROOT_DIR/.build_iconset"
mkdir -p "$ICONSET"
swift "$ROOT_DIR/Resources/make_icon.swift" "$ICONSET"
iconutil -c icns "$ICONSET" -o "$RES_DIR/AppIcon.icns"
rm -rf "$ROOT_DIR/.build_iconset"

# 2. Copy Info.plist
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS/Info.plist"

# 3. Compile native macOS SwiftUI + IOKit binary
swiftc -O -swift-version 5 \
  "$ROOT_DIR/Sources/K648Layout.swift" \
  "$ROOT_DIR/Sources/RGBModels.swift" \
  "$ROOT_DIR/Sources/HIDController.swift" \
  "$ROOT_DIR/Sources/RGBEngine.swift" \
  "$ROOT_DIR/Sources/ContentView.swift" \
  "$ROOT_DIR/Sources/AppMain.swift" \
  -framework SwiftUI \
  -framework AppKit \
  -framework IOKit \
  -framework Foundation \
  -framework QuartzCore \
  -o "$MACOS_DIR/RedragonOlafRGB"

# 4. Ad-hoc sign bundle so macOS TCC remembers Input Monitoring permission cleanly
codesign --force --deep --sign - "$APP_DIR"

echo "==> Build succeeded: $APP_DIR"
