#!/usr/bin/env bash
# v2 payload entrypoint: run RIT in a headless X session and expose it as a web
# desktop (noVNC) + its REST API. This amd64 image is what the macOS v2 wrapper
# runs inside an arm64 microVM via FEX — the GUI shows in the app's window.
set -u

export WINEPREFIX=/opt/rit-prefix WINEARCH=win32 WINEDEBUG=-all
export WINEDLLOVERRIDES="mscoree=n;mshtml=d" DISPLAY=:99 HOME=/root XDG_RUNTIME_DIR=/tmp/xdg
mkdir -p /tmp/xdg /var/log/rit

Xvfb :99 -screen 0 1280x800x24 >/var/log/rit/xvfb.log 2>&1 &
sleep 2
openbox >/var/log/rit/openbox.log 2>&1 &
sleep 1

CLIENT="$WINEPREFIX/drive_c/Program Files/Rotman/RIT User Application/Client.exe"
echo "== launching RIT =="
wine "$CLIENT" >/var/log/rit/rit.log 2>&1 &

# VNC server bound to the X display, and the noVNC web client over it.
x11vnc -display :99 -forever -shared -nopw -rfbport 5900 -bg -o /var/log/rit/x11vnc.log
websockify --web=/usr/share/novnc 6080 localhost:5900 >/var/log/rit/novnc.log 2>&1 &

echo "================================================================"
echo " RIT desktop : http://localhost:6080/vnc.html"
echo " RIT REST API: http://localhost:9999/v1/..."
echo "================================================================"

# Wait for the API to confirm RIT is up (informational).
for i in $(seq 1 40); do
  sleep 3
  if ss -ltn 2>/dev/null | grep -q ':9999'; then echo "RIT API listening on :9999"; break; fi
done

wait
