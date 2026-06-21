#!/usr/bin/env bash
# Slimmest display: ONE process (Xvnc = X server + VNC server) + Wine desktop mode
# (no Xvfb, no x11vnc, no noVNC, no websockify, no window manager).
# Exposes VNC on :5900 (native client) and RIT's REST API on :9999.
set -u
export WINEPREFIX=/opt/rit-prefix WINEARCH=win32 WINEDEBUG=-all
export WINEDLLOVERRIDES="mscoree=n;mshtml=d" DISPLAY=:99 HOME=/root XDG_RUNTIME_DIR=/tmp/xdg
mkdir -p /tmp/xdg /var/log/rit

# Xvnc serves the X display directly over VNC — no separate VNC server needed.
Xvnc :99 -geometry 1280x800 -depth 24 -SecurityTypes None -AlwaysShared \
     -rfbport 5900 >/var/log/rit/xvnc.log 2>&1 &
sleep 3

CLIENT="$WINEPREFIX/drive_c/Program Files/Rotman/RIT User Application/Client.exe"
echo "== launching RIT in Wine desktop mode (single window, no WM) =="
wine explorer /desktop=RIT,1280x800 "$CLIENT" >/var/log/rit/rit.log 2>&1 &

echo "VNC: connect a native client to :5900   |   RIT API: :9999"
for i in $(seq 1 40); do
  sleep 3
  ss -ltn 2>/dev/null | grep -q ':9999' && { echo "RIT API listening on :9999"; break; }
done
wait
