#!/usr/bin/env bash
# Build RIT.app — a double-clickable .app from the RITApp Swift sources, bundling
# RoyalVNC. Run on macOS (Apple Silicon). Ad-hoc signs by default; set SIGN_ID to
# a "Developer ID Application: …" identity to sign for distribution.
#
#   ./build-app.sh                 # -> build/RIT.app (ad-hoc, for local use)
#   SIGN_ID="Developer ID …" ./build-app.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
APP="$HERE/build/RIT.app"

echo "==> swift build (release)"
swift build -c release
BIN="$(swift build -c release --show-bin-path)"

echo "==> assemble bundle"
rm -rf "$HERE/build"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN/RITApp" "$APP/Contents/MacOS/RITApp"
cp "$HERE/Info.plist" "$APP/Contents/Info.plist"

# Icon: generate RIT.icns from the repo's iconset if present.
ICONSET="$HERE/../../../RIT.iconset"
if [ -d "$ICONSET" ]; then
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/RIT.icns" 2>/dev/null || true
fi

# Bundle the RoyalVNCKit dylib next to the binary and point the rpath at it.
if [ -f "$BIN/libRoyalVNCKit.dylib" ]; then
  cp "$BIN/libRoyalVNCKit.dylib" "$APP/Contents/Frameworks/"
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/RITApp" 2>/dev/null || true
fi

echo "==> sign (${SIGN_ID:-ad-hoc})"
codesign --force --deep --options runtime --sign "${SIGN_ID:--}" "$APP" 2>&1 | tail -2

echo "==> done: $APP"
echo "   Run:  open '$APP'    (the MVP connects to the Lima VM's :5900; start it with v2/macos/lima/run-rit.sh)"
echo "   Pack: hdiutil create -volname RIT -srcfolder '$APP' -ov -format UDZO build/RIT-mac-apple-silicon.dmg"
