#!/bin/bash
# Builds Molekit.app into ./build. Usage: ./build.sh [--install]
#   --install  also copies the app to /Applications
set -euo pipefail
cd "$(dirname "$0")"

VERSION="0.1.0"
APP="build/Molekit.app"

swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Molekit" "$APP/Contents/MacOS/Molekit"
# SwiftPM resource bundle (translations)
cp -R "$BIN_DIR/Molekit_Molekit.bundle" "$APP/Contents/Resources/"
[ -f Assets/Molekit.icns ] && cp Assets/Molekit.icns "$APP/Contents/Resources/Molekit.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Molekit</string>
  <key>CFBundleDisplayName</key><string>Molekit</string>
  <key>CFBundleIdentifier</key><string>io.github.truenihilisme.molekit</string>
  <key>CFBundleExecutable</key><string>Molekit</string>
  <key>CFBundleIconFile</key><string>Molekit</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>uk</string></array>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Molekit opens Terminal to run interactive mo commands such as mo uninstall.</string>
</dict>
</plist>
PLIST

# Ad-hoc signature so macOS can run it locally. Not notarized.
codesign --force --deep --sign - "$APP"
echo "Built $APP ($VERSION)"

if [[ "${1:-}" == "--install" ]]; then
  rm -rf /Applications/Molekit.app
  cp -R "$APP" /Applications/
  echo "Installed to /Applications/Molekit.app"
fi
