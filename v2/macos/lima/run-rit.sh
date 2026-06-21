#!/usr/bin/env bash
# Run RIT under FEX inside the Lima arm64 VM. Exposes RIT's API on :9999 and a VNC
# view of the GUI on :5900 (both forwarded to the Mac's localhost by Lima).
# Reuses the proven green-CI FEX recipe (validate-fex-arm64.yml).
set -euo pipefail
IMG="${RIT_IMG:-ghcr.io/qu-jieniu/rit-in-wine/rit-payload:latest}"

if [ ! -f "$HOME/.fex-emu/RootFS/rit/.ready" ]; then
  echo "== first run: pull the payload + build the FEX RootFS =="
  sudo docker pull --platform linux/amd64 "$IMG"
  cid=$(sudo docker create --platform linux/amd64 "$IMG")
  mkdir -p "$HOME/.fex-emu/RootFS/rit"
  sudo docker export "$cid" | sudo tar -C "$HOME/.fex-emu/RootFS/rit" -xf -
  sudo docker rm "$cid"
  sudo chown -R "$(id -u):$(id -g)" "$HOME/.fex-emu"
  # Wine + prefix must live on host-passthrough paths — Wine's case-insensitive
  # NtCreateFile traversal fails on FEX rootfs dirs (the proven fix).
  sudo rm -rf /opt/wine-stable /opt/rit-prefix
  sudo mv "$HOME/.fex-emu/RootFS/rit/opt/wine-stable" /opt/wine-stable
  sudo mv "$HOME/.fex-emu/RootFS/rit/opt/rit-prefix"  /opt/rit-prefix
  sudo chown -R "$(id -u):$(id -g)" /opt/wine-stable /opt/rit-prefix
  printf '{"Config":{"RootFS":"rit"}}\n' > "$HOME/.fex-emu/Config.json"
  touch "$HOME/.fex-emu/RootFS/rit/.ready"
fi

# Native arm64 display + VNC (the x86 Xvfb/x11vnc inside the payload won't run
# under FEX, so we drive the display from the arm64 host side).
pkill -f "Xvfb :99" 2>/dev/null || true
pkill -f "x11vnc"   2>/dev/null || true
Xvfb :99 -screen 0 1280x800x24 -listen tcp -ac >/tmp/xvfb.log 2>&1 &
sleep 3
# -noshm is required: the display is reached over TCP (127.0.0.1:99), and MIT
# shared-memory (XShmAttach) fails over TCP — without it x11vnc crashes on connect.
x11vnc -display 127.0.0.1:99 -rfbport 5900 -forever -shared -nopw -noshm -quiet >/tmp/x11vnc.log 2>&1 &

cat > "$HOME/.fex-emu/RootFS/rit/run.sh" <<'SH'
set -u
export WINEPREFIX=/opt/rit-prefix WINEARCH=win32 WINEDEBUG=-all
export WINEDLLOVERRIDES="mscoree=n;mshtml=d" DISPLAY=127.0.0.1:99 HOME=/root XDG_RUNTIME_DIR=/tmp/xdg
export WINELOADER=/opt/wine-stable/bin/wine PATH=/opt/wine-stable/bin:/usr/bin:/bin
mkdir -p /tmp/xdg
CLIENT="$WINEPREFIX/drive_c/Program Files/Rotman/RIT User Application/Client.exe"
echo "== launching RIT under FEX (slow on first JIT — be patient) =="
wine "$CLIENT" >/tmp/rit.log 2>&1 &
for i in $(seq 1 120); do
  sleep 5
  ss -ltn 2>/dev/null | grep -q ":9999" && { echo ">>> RIT API listening on :9999 after $((i*5))s"; break; }
done
echo "== rit.log tail =="; tail -8 /tmp/rit.log
wait
SH

echo "== starting RIT under FEX =="
echo "   API  -> Mac:  curl http://localhost:9999/v1/case"
echo "   GUI  -> Mac:  open vnc://localhost:5900"
FEXBash -c 'bash /run.sh'
