#!/usr/bin/env bash
# Build RIT-aarch64.AppImage on an arm64 host (needs docker + curl + GHCR access
# for the amd64 payload). Bundles Ubuntu-arm64 + FEX + bubblewrap + the amd64
# Wine/RIT (as FEX's x86 RootFS). See AppRun.arm64.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${OUT:-$HERE/out}"
IMG="${IMG:-rit-appimage-rootfs-arm64}"
CRT="${CRT:-$(command -v docker || command -v podman)}"
APPDIR="$(mktemp -d)/RIT.AppDir"
mkdir -p "$APPDIR/rootfs" "$OUT"

echo "==> build arm64 rootfs (Ubuntu + FEX + bubblewrap + amd64 payload) [$CRT]"
"$CRT" build -f "$HERE/Dockerfile.appimage-arm64" -t "$IMG" "$HERE"

echo "==> export the rootfs"
cid=$("$CRT" create "$IMG")
"$CRT" export "$cid" | tar -C "$APPDIR/rootfs" -xf - \
    --exclude='proc/*' --exclude='sys/*' --exclude='dev/*' 2>/dev/null || true
"$CRT" rm "$cid" >/dev/null
test -e "$APPDIR/rootfs/usr/bin/bwrap"
test -e "$APPDIR/rootfs/usr/bin/FEXBash"

echo "==> AppRun + desktop + icon"
cp "$HERE/AppRun.arm64" "$APPDIR/AppRun"; chmod +x "$APPDIR/AppRun"
cp "$HERE/rit.desktop" "$APPDIR/rit.desktop"
cp "$HERE/rit-icon.png" "$APPDIR/rit.png"

echo "==> package with arm64 appimagetool"
TOOL="${APPIMAGETOOL:-/tmp/appimagetool-aarch64}"
if [ ! -x "$TOOL" ]; then
    curl -fsSL "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-aarch64.AppImage" -o "$TOOL"
    chmod +x "$TOOL"
fi
ARCH=aarch64 "$TOOL" --appimage-extract-and-run "$APPDIR" "$OUT/RIT-aarch64.AppImage" 2>&1 | tail -6
ls -la "$OUT/"
rm -rf "$(dirname "$APPDIR")"
