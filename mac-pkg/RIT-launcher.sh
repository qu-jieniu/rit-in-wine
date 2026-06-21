#!/bin/bash
# RIT.app/Contents/MacOS/RIT
#
# The single master process for the app. It owns the entire Wine session and
# tears it ALL down on exit -- so no wineserver / services.exe / winedevice /
# plugplay / rpcss / explorer / http.sys host linger after RIT is closed (the
# classic "app won't quit, Dock keeps bouncing, CPU stays busy" Wine bug).
#
# No Wineskin, no CrossOver, no bottle manager: just bundled Wine + our baked
# prefix + this script.
set -u

# --- locate bundled resources -------------------------------------------------
RES="$(cd "$(dirname "$0")/../Resources" && pwd)"
WINEDIR="$RES/wine"
export WINELOADER="$WINEDIR/bin/wine"
export WINESERVER="$WINEDIR/bin/wineserver"
export PATH="$WINEDIR/bin:$PATH"

# --- per-user writable prefix -------------------------------------------------
SUPPORT="$HOME/Library/Application Support/RIT"
export WINEPREFIX="$SUPPORT/prefix"
export WINEARCH=win32
export WINEDEBUG=-all
export WINEDLLOVERRIDES="mscoree=n;mshtml=d"   # native .NET 4.8, no gecko
mkdir -p "$SUPPORT"

# --- single instance ----------------------------------------------------------
LOCK="$SUPPORT/rit.lock"
if [ -e "$LOCK" ] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then
    open -a "$(cat "$SUPPORT/.appdir" 2>/dev/null)" 2>/dev/null || true
    exit 0
fi
echo $$ > "$LOCK"

# --- first run: expand the bundled compressed prefix into the writable area ---
if [ ! -f "$WINEPREFIX/.rit-ready" ]; then
    rm -rf "$WINEPREFIX" "$SUPPORT/rit-prefix"
    # bsdtar auto-detects zstd/xz/gzip; this is the one-time unpack.
    tar -xf "$RES/prefix.tar.zst" -C "$SUPPORT"
    mv "$SUPPORT/rit-prefix" "$WINEPREFIX"
    touch "$WINEPREFIX/.rit-ready"
fi

CLIENT="$WINEPREFIX/drive_c/Program Files/Rotman/RIT User Application/Client.exe"

# --- teardown on ANY exit path (clean close, force-quit, crash, signal) -------
cleanup() {
    "$WINESERVER" -k >/dev/null 2>&1 || true
    rm -f "$LOCK"
}
trap cleanup EXIT INT TERM HUP

# Run RIT in the foreground. Wine blocks here until RIT itself exits; then the
# trap fires and wineserver -k reaps the whole background process tree.
"$WINELOADER" "$CLIENT" "$@"
