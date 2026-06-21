#!/usr/bin/env bash
# Build-time: install the pinned RIT MSI INTO the baked prefix, so the prefix
# ships with RIT already present (for the AppImage / .pkg payload).
set -eu
VER="${RIT_VERSION:-1.8.420}"
export WINEPREFIX=/opt/rit-prefix WINEARCH=${WINEARCH:-win32} WINEDEBUG=-all
export DISPLAY=:99 HOME=/root XDG_RUNTIME_DIR=/tmp/xdg
mkdir -p /tmp/xdg
Xvfb :99 -screen 0 1280x800x24 >/dev/null 2>&1 &
sleep 2

curl -fSL --retry 3 "https://rit.306w.ca/release/${VER}/RIT%20User%20Application-${VER}.msi" -o /tmp/rit.msi
wine msiexec /i /tmp/rit.msi /qn
timeout 60 wineserver -w
test -f "$WINEPREFIX/drive_c/Program Files/Rotman/RIT User Application/Client.exe"
echo "RIT $VER baked into $WINEPREFIX"
