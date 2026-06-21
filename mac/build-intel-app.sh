#!/usr/bin/env bash
# Assemble RIT.app for Intel Macs (native stock Wine) and pack a .dmg.
# Runs on a macOS x86_64 runner (GitHub `macos-13`). Inputs:
#   WINE_TARBALL  : stock Wine 11 built-from-source for macOS x86_64 (vendored —
#                   not gcenx; built in CI so nothing external can disappear).
#   PREFIX_TAR    : the win32 prefix (.NET 4.8 + RIT MSI baked), exported from
#                   rit-prefix:installed via `podman export | zstd`.
#   SIGN_ID       : "Developer ID Application: …"   (optional; unsigned if unset)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HERE/build/RIT.app"
rm -rf "$HERE/build"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "==> Info.plist + icon"
cp "$HERE/Info.plist" "$APP/Contents/Info.plist"
[ -f "$HERE/RIT.icns" ] && cp "$HERE/RIT.icns" "$APP/Contents/Resources/RIT.icns" || true

echo "==> compile the launcher (x86_64, Cocoa)"
clang -arch x86_64 -framework Cocoa -O2 -o "$APP/Contents/MacOS/RITLauncher" "$HERE/RITLauncher.m"

echo "==> bundle stock Wine engine (x86_64) -> Resources/wine"
mkdir -p "$APP/Contents/Resources/wine"
tar -C "$APP/Contents/Resources/wine" --strip-components=1 -xf "${WINE_TARBALL:?set WINE_TARBALL}"

echo "==> bundle the win32 prefix (.NET 4.8 + RIT) -> Resources/prefix"
mkdir -p "$APP/Contents/Resources/prefix"
zstd -dc "${PREFIX_TAR:?set PREFIX_TAR}" | tar -C "$APP/Contents/Resources/prefix" -xf -

echo "==> sign (hardened runtime) + notarize"
if [ -n "${SIGN_ID:-}" ]; then
  # Wine ships unsigned dylibs -> allow library validation off for the bundle.
  cat > "$HERE/wine.entitlements" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.cs.allow-unsigned-executable-memory</key><true/>
  <key>com.apple.security.cs.disable-library-validation</key><true/>
  <key>com.apple.security.cs.allow-jit</key><true/>
</dict></plist>
EOF
  find "$APP/Contents/Resources/wine" -type f \( -name '*.dylib' -o -name '*.so' -o -perm -u+x \) \
    -exec codesign --force --options runtime --timestamp \
      --entitlements "$HERE/wine.entitlements" --sign "$SIGN_ID" {} + 2>/dev/null || true
  codesign --force --options runtime --timestamp --entitlements "$HERE/wine.entitlements" \
    --sign "$SIGN_ID" "$APP/Contents/MacOS/RITLauncher"
  codesign --force --options runtime --timestamp --entitlements "$HERE/wine.entitlements" \
    --sign "$SIGN_ID" "$APP"
fi

echo "==> pack .dmg (drag-install)"
DMG="$HERE/build/RIT-mac-intel.dmg"
STAGE="$HERE/build/dmg"; mkdir -p "$STAGE"; cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Rotman Interactive Trader" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
if [ -n "${SIGN_ID:-}" ]; then codesign --force --sign "$SIGN_ID" "$DMG" || true; fi
echo "==> done: $DMG"
# Notarization (when NOTARY_* are set) is run by the workflow:
#   xcrun notarytool submit "$DMG" --apple-id … --team-id … --password … --wait
#   xcrun stapler staple "$DMG"
