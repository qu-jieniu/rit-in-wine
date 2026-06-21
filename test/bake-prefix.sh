#!/usr/bin/env bash
# Build-time: bake a reusable Wine prefix with .NET 4.8 installed, so MSI/app
# experiments (and the real installer) run on top without re-doing dotnet48.
set -eu
export WINEPREFIX=/opt/rit-prefix WINEARCH=${WINEARCH:-win64} WINEDEBUG=-all
export DISPLAY=:99 HOME=/root XDG_RUNTIME_DIR=/tmp/xdg
mkdir -p /tmp/xdg

Xvfb :99 -screen 0 1280x800x24 >/dev/null 2>&1 &
sleep 2

# mono/gecko disabled during init so the headless "install?" dialog can't hang us.
WINEDLLOVERRIDES="mscoree=d;mshtml=d" timeout 180 wineboot --init
timeout 120 wineserver -w
timeout 1500 winetricks -q dotnet48
timeout 120 wineserver -w
echo "baked prefix at $WINEPREFIX with .NET 4.8"
