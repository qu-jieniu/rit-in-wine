#!/usr/bin/with-contenv bash
# First-boot setup for RIT under Wine.
# Idempotent: a marker file in $WINEPREFIX guards each step.

set -u

export WINEPREFIX=/config/.wine
export WINEARCH=win64
export WINEDEBUG=-all
export HOME=/config
export DISPLAY=:99

mkdir -p /config
chown -R abc:abc /config

run_as_abc() {
    s6-setuidgid abc env \
        HOME=/config \
        WINEPREFIX="$WINEPREFIX" \
        WINEARCH="$WINEARCH" \
        WINEDEBUG="$WINEDEBUG" \
        DISPLAY="$DISPLAY" \
        PATH=/usr/local/bin:/usr/bin:/bin \
        "$@"
}

# Headless X server for wine to talk to during install.
if ! pgrep -f "Xvfb :99" >/dev/null 2>&1; then
    Xvfb :99 -screen 0 1280x800x24 &
    sleep 1
fi

if [ ! -f "$WINEPREFIX/.wine-initialized" ]; then
    echo "[rit-init] initializing wine prefix at $WINEPREFIX"
    run_as_abc wineboot --init
    run_as_abc wineserver -w
    touch "$WINEPREFIX/.wine-initialized"
    chown abc:abc "$WINEPREFIX/.wine-initialized"
fi

if [ ! -f "$WINEPREFIX/.dotnet48-installed" ]; then
    echo "[rit-init] installing .NET Framework 4.8 (this takes several minutes)"
    run_as_abc winetricks -q --force dotnet48 || {
        echo "[rit-init] dotnet48 install failed — RIT will not run until this succeeds." >&2
        exit 0
    }
    touch "$WINEPREFIX/.dotnet48-installed"
    chown abc:abc "$WINEPREFIX/.dotnet48-installed"
fi

CLIENT_APP="$WINEPREFIX/drive_c/Client.application"
if [ ! -f "$CLIENT_APP" ]; then
    echo "[rit-init] downloading RIT Client.application"
    curl -fsSL "http://rit.306w.ca/client/Client.application" -o "$CLIENT_APP" || \
        echo "[rit-init] could not download Client.application — check network" >&2
    chown abc:abc "$CLIENT_APP" 2>/dev/null || true
fi

DESKTOP_DIR=/config/Desktop
mkdir -p "$DESKTOP_DIR"
LAUNCHER="$DESKTOP_DIR/RIT.desktop"
if [ ! -f "$LAUNCHER" ]; then
    cat > "$LAUNCHER" <<'EOF'
[Desktop Entry]
Type=Application
Name=RIT
Comment=Rotman Interactive Trader
Exec=/usr/local/bin/rit
Icon=applications-other
Terminal=false
Categories=Office;Finance;
EOF
    chmod +x "$LAUNCHER"
    chown abc:abc "$LAUNCHER"
fi

echo "[rit-init] ready — double-click 'RIT' on the desktop, or run 'rit' in a terminal."
