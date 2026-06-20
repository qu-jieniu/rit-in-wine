#!/usr/bin/env bash
# Runs urltest.exe under upstream Wine with either the patched or the stock
# http.sys, and propagates its PASS/FAIL exit code.
#
#   run-test.sh patched   -> overwrite Wine's builtin http.sys with our patched PE; expect PASS
#   run-test.sh stock     -> leave Wine's shipped http.sys in place;               expect FAIL
#
# No CrossOver, no .NET, no winetricks.
set -u

MODE="${1:-patched}"
PORT="${2:-9971}"
PATCHED_DRIVER="${PATCHED_DRIVER:-/test/http.sys}"

export WINEPREFIX="${WINEPREFIX:-/root/.wine}"
export WINEARCH="${WINEARCH:-win64}"
export WINEDEBUG="${WINEDEBUG:--all}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/xdg}"
mkdir -p "$XDG_RUNTIME_DIR"

echo "== wine version: $(wine --version) =="

# urltest is a console app and needs no display. Initialise the prefix headlessly.
wineboot --init >/dev/null 2>&1
wineserver -w

# Locate Wine's builtin http.sys (the driver actually loaded at runtime).
DRIVER_PATH="$(find /opt /usr -name http.sys -path '*x86_64-windows*' 2>/dev/null | head -1)"
if [[ -z "$DRIVER_PATH" ]]; then
    DRIVER_PATH="$(find /opt /usr -name http.sys -path '*aarch64-windows*' 2>/dev/null | head -1)"
fi
echo "== wine builtin driver: $DRIVER_PATH =="

if [[ "$MODE" == "patched" ]]; then
    echo "== installing PATCHED http.sys =="
    cp "$PATCHED_DRIVER" "$DRIVER_PATH"
    # also drop into the prefix in case the loader prefers it there
    mkdir -p "$WINEPREFIX/drive_c/windows/system32/drivers"
    cp "$PATCHED_DRIVER" "$WINEPREFIX/drive_c/windows/system32/drivers/http.sys"
else
    echo "== using STOCK http.sys (control) =="
fi

echo "== running urltest on port $PORT =="
wine /test/urltest.exe "$PORT"
rc=$?
echo "== urltest exit=$rc (0=PASS, 1=FAIL/hang, 2=setup error) =="
wineserver -k 2>/dev/null || true
exit $rc
