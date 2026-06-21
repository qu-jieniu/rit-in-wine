#!/usr/bin/env bash
# Build a signed, notarized RIT.pkg on macOS. No Wineskin, no CrossOver.
#
# Assembles a hand-rolled RIT.app = bundled upstream Wine + our baked prefix +
# the single-master launcher, then wraps it in a Developer ID-signed .pkg that
# installs to /Applications and strips quarantine on install.
#
# Inputs (env):
#   PREFIX_TARBALL   path to the Linux-baked prefix (rit-prefix.tar.zst)   [required]
#   WINE_PKG_URL     upstream Wine macOS package/tarball to bundle         [required]
#   APP_IDENTITY     "Developer ID Application: NAME (TEAMID)"             [required to sign]
#   INSTALLER_IDENTITY "Developer ID Installer: NAME (TEAMID)"            [required to sign pkg]
#   NOTARY_PROFILE   `xcrun notarytool store-credentials` profile name     [required to notarize]
set -euo pipefail
[[ "$(uname)" == "Darwin" ]] || { echo "run on macOS"; exit 1; }

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
VER="$(plutil -extract version raw -o - "$ROOT/rit.lock.json" 2>/dev/null || python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$ROOT/rit.lock.json")"
BUILD="$HERE/build"; APP="$BUILD/RIT.app"; RES="$APP/Contents/Resources"
rm -rf "$BUILD"; mkdir -p "$RES" "$APP/Contents/MacOS"

echo "==> 1. bundled Wine engine (the bottle replacement)"
curl -fSL "$WINE_PKG_URL" -o "$BUILD/wine.pkg.src"
#   Expand whatever form it is (tar or pkg payload) into Resources/wine.
mkdir -p "$RES/wine"
if tar -tf "$BUILD/wine.pkg.src" >/dev/null 2>&1; then
    tar -xf "$BUILD/wine.pkg.src" -C "$RES/wine" --strip-components=1
else
    pkgutil --expand-full "$BUILD/wine.pkg.src" "$BUILD/wine-expanded"
    cp -R "$BUILD"/wine-expanded/*/Payload/* "$RES/wine/" 2>/dev/null || \
        cp -R "$BUILD"/wine-expanded/* "$RES/wine/"
fi

echo "==> 2. baked prefix (compressed, expanded on first run)"
cp "$PREFIX_TARBALL" "$RES/prefix.tar.zst"

echo "==> 3. launcher (single master / clean teardown)"
cp "$HERE/RIT-launcher.sh" "$APP/Contents/MacOS/RIT"
chmod +x "$APP/Contents/MacOS/RIT"

echo "==> 4. icon: rotman.ico -> rit.icns via iconutil"
ICONSET="$BUILD/rit.iconset"; mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
    sips -z $s $s     "$HERE/rit-icon.png" --out "$ICONSET/icon_${s}x${s}.png"      >/dev/null
    sips -z $((s*2)) $((s*2)) "$HERE/rit-icon.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$RES/rit.icns"

echo "==> 5. Info.plist"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>RIT</string>
  <key>CFBundleDisplayName</key><string>Rotman Interactive Trader</string>
  <key>CFBundleIdentifier</key><string>ca.rotman.rit</string>
  <key>CFBundleVersion</key><string>${VER}</string>
  <key>CFBundleShortVersionString</key><string>${VER}</string>
  <key>CFBundleExecutable</key><string>RIT</string>
  <key>CFBundleIconFile</key><string>rit.icns</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
</dict></plist>
PLIST

echo "==> 6. codesign the .app (deep, hardened runtime)"
if [[ -n "${APP_IDENTITY:-}" ]]; then
    codesign --force --deep --options runtime --timestamp \
        --entitlements <(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.cs.allow-jit</key><true/>
  <key>com.apple.security.cs.allow-unsigned-executable-memory</key><true/>
  <key>com.apple.security.cs.disable-library-validation</key><true/>
</dict></plist>
EOF
) --sign "$APP_IDENTITY" "$APP"
else
    echo "   (no APP_IDENTITY -- ad-hoc sign)"; codesign --force --deep --sign - "$APP"
fi

echo "==> 7. build component pkg with a quarantine-stripping postinstall"
SCRIPTS="$BUILD/scripts"; mkdir -p "$SCRIPTS"
cat > "$SCRIPTS/postinstall" <<'POST'
#!/bin/bash
xattr -dr com.apple.quarantine /Applications/RIT.app 2>/dev/null || true
exit 0
POST
chmod +x "$SCRIPTS/postinstall"

pkgbuild --root "$BUILD" --component-plist /dev/stdin \
         --install-location /Applications \
         --scripts "$SCRIPTS" \
         --identifier ca.rotman.rit.pkg --version "$VER" \
         "$BUILD/RIT-component.pkg" <<'CPLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><array><dict>
  <key>BundleIsRelocatable</key><false/>
  <key>RootRelativeBundlePath</key><string>RIT.app</string>
</dict></array></plist>
CPLIST

PKG="$HERE/RIT-${VER}.pkg"
if [[ -n "${INSTALLER_IDENTITY:-}" ]]; then
    productbuild --package "$BUILD/RIT-component.pkg" --sign "$INSTALLER_IDENTITY" "$PKG"
else
    productbuild --package "$BUILD/RIT-component.pkg" "$PKG"
fi

echo "==> 8. notarize + staple"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$PKG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$PKG"
fi

echo "DONE: $PKG"
