#!/usr/bin/env bash
# Runs on the baked .NET 4.8 prefix. Installs a pinned RIT MSI with a verbose
# log, reports exactly what landed and where, then tries to launch + hit the API.
set -u

VER="${RIT_VERSION:-1.8.420}"
export WINEPREFIX=/opt/rit-prefix WINEARCH=${WINEARCH:-win64} WINEDEBUG=-all
export DISPLAY=:99 HOME=/root XDG_RUNTIME_DIR=/tmp/xdg
mkdir -p /tmp/xdg
Xvfb :99 -screen 0 1280x800x24 >/dev/null 2>&1 &
sleep 2

echo "== wine $(wine --version), .NET 4.8 prebaked =="

if [[ -f /test/rit.msi ]]; then
    echo "== using provided MSI (/test/rit.msi) =="
    cp /test/rit.msi /tmp/rit.msi
else
    echo "== fetch MSI $VER =="
    curl -fSL --retry 3 "https://rit.306w.ca/release/${VER}/RIT%20User%20Application-${VER}.msi" -o /tmp/rit.msi \
        || { echo "VERDICT: MSI download failed"; exit 4; }
fi

echo "== msiexec /i /qn with verbose log =="
wine msiexec /i /tmp/rit.msi /qn /l*v 'C:\install.log'
echo "   msiexec rc=$?"
timeout 60 wineserver -w

LOG="$WINEPREFIX/drive_c/install.log"
if [[ -f "$LOG" ]]; then
    echo "== install.log: errors / launch conditions / 'Installation success or error status' =="
    iconv -f UTF-16LE -t UTF-8 "$LOG" 2>/dev/null | \
        grep -iE "error|condition|disallowed|success or error|return value 3|cannot|not installed|requires" | tail -30
fi

echo "== what actually landed (excluding Wine builtins) =="
find "$WINEPREFIX/drive_c" \( -iname '*.exe' -o -iname '*.application' \) 2>/dev/null \
    | grep -ivE '/windows/|system32|syswow64|/Mono/|/Microsoft\.NET/' \
    | grep -iE 'rotman|RIT|client|trader' | head

EXE="$(find "$WINEPREFIX/drive_c" -ipath '*Rotman*' -iname 'Client.exe' 2>/dev/null | head -1)"
if [[ -z "$EXE" ]]; then
    echo "VERDICT: MSI ran but installed no RIT app (see log above)"; exit 5
fi
echo "== RIT exe: $EXE =="
echo "== arch (decides if we can drop 32-bit Wine/.NET): =="
winedump "$EXE" 2>/dev/null | grep -iE "Machine|Magic|x86-64|i386" | head -3 || true

echo "== launch =="
wine "$EXE" >/tmp/rit.log 2>&1 &
bound=0
for i in $(seq 1 25); do
    sleep 3
    ss -ltn 2>/dev/null | grep -q ':9999' && { bound=1; echo "   :9999 listening"; break; }
done
if [[ "$bound" == "1" ]]; then
    timeout 8 curl -s -o /dev/null -w "   HTTP %{http_code} in %{time_total}s\n" "http://127.0.0.1:9999/v1/case" \
        && echo "VERDICT: PASS -- RIT API responds on stock Wine 11" \
        || echo "VERDICT: API bound but request hung"
else
    echo "== rit.log tail =="; tail -20 /tmp/rit.log
    echo "VERDICT: installed+launched, listener not confirmed headless (may need login)"
fi
wineserver -k 2>/dev/null || true
