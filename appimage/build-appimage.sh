#!/usr/bin/env bash
# Build the portable RIT-x86_64.AppImage on the host (needs podman + curl).
#
# Bundles the whole stock-WineHQ + RIT userspace (a Debian rootfs + bubblewrap)
# and an AppRun that runs RIT inside it via bwrap. Result runs on ANY 64-bit Linux
# host with zero dependencies (no 32-bit libs) — display is the host's native X
# (or XWayland). See AppRun for the runtime model.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${OUT:-$HERE/out}"
ROOTFS_IMG="${ROOTFS_IMG:-rit-appimage-rootfs}"
CRT="${CRT:-$(command -v docker || command -v podman)}"   # docker (CI) or podman (local)
APPDIR="$(mktemp -d)/RIT.AppDir"
mkdir -p "$APPDIR/rootfs" "$OUT"

echo "==> build rootfs image (minimal payload + bubblewrap) [$CRT]"
"$CRT" build -f "$HERE/Dockerfile.appimage" -t "$ROOTFS_IMG" "$HERE"

echo "==> export the rootfs"
cid=$("$CRT" create "$ROOTFS_IMG")
"$CRT" export "$cid" | tar -C "$APPDIR/rootfs" -xf - \
    --exclude='proc/*' --exclude='sys/*' --exclude='dev/*' 2>/dev/null || true
"$CRT" rm "$cid" >/dev/null
# Existence only (wine is an absolute symlink into the rootfs — `test -x` would
# wrongly resolve it against the host root and fail).
test -e "$APPDIR/rootfs/usr/bin/bwrap"
test -e "$APPDIR/rootfs/usr/bin/wine"

echo "==> AppRun + desktop + icon"
cp "$HERE/AppRun" "$APPDIR/AppRun"; chmod +x "$APPDIR/AppRun"
cp "$HERE/rit.desktop" "$APPDIR/rit.desktop"
cp "$HERE/rit-icon.png" "$APPDIR/rit.png"

echo "==> package with appimagetool"
TOOL="${APPIMAGETOOL:-/tmp/appimagetool}"
if [ ! -x "$TOOL" ]; then
    curl -fsSL "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage" -o "$TOOL"
    chmod +x "$TOOL"
fi
ARCH=x86_64 "$TOOL" --appimage-extract-and-run "$APPDIR" "$OUT/RIT-x86_64.AppImage" 2>&1 | tail -6
ls -la "$OUT/"
rm -rf "$(dirname "$APPDIR")"
