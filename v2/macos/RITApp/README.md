# RIT.app — native macOS Apple-Silicon app (MVP)

Embeds RIT's GUI in a native macOS window via **RoyalVNC**, talking to the x86
Wine/RIT running **Rosetta-free** (FEX) inside an arm64 Linux VM.

## ✅ Validated LIVE on real hardware
Confirmed end-to-end on an **Apple M3 Max, macOS 26.3.1, Swift 6.3.2** (driven over
an SSH reverse tunnel through the Mac's firewall):

| Layer | Result |
|---|---|
| **Apple Virtualization.framework** (via Lima) boots arm64 Ubuntu | ✅ no admin, no MDM block |
| **FEX** runs x86 Wine 11 + RIT, Rosetta-free | ✅ bound `:9999` in ~10 s |
| **RIT REST API** → Mac `localhost:9999` | ✅ HTTP 401 (Python/R ready) |
| **RIT GUI** embedded in a native macOS window (RoyalVNC `VNCCAFramebufferView`) | ✅ renders + **mouse/keyboard input works** (typed Trader ID / Server) |
| Outbound net to `flserver.rotman.utoronto.ca:10000` | ✅ reachable from the VM |

So the entire Apple-Silicon architecture is **proven**. macOS floor confirmed well
below 14 → set to **13** (VZ Linux-VM support starts at 13).

## Reproduce on any Apple-Silicon Mac

```bash
# 1. Boot the VM + RIT (one-time payload pull from GHCR, then FEX runs RIT)
brew install lima            # or: download the limactl release tarball (no admin)
limactl start  v2/macos/lima/rit.yaml
limactl shell  rit bash v2/macos/lima/run-rit.sh     # waits for ">>> RIT API listening on :9999"

# 2. Build + run the native app
cd v2/macos/RITApp
swift build -c release        # pulls RoyalVNC, links clean (verified)
.build/release/RITApp         # native window shows RIT; VNC pass 'ritvnc' auto-applied
#   (GUI apps must launch from your own session, not SSH — a Terminal.app run, or `open RIT.app`)

# 3. Package as a double-click .app
./build-app.sh                # -> build/RIT.app   (ad-hoc; SIGN_ID=… for Developer ID)
```

## Design notes / gotchas learned live
- **RoyalVNC callbacks are off-main** — all AppKit UI must `DispatchQueue.main.async`
  (an early crash: "NSWindow geometry should only be modified on the main thread").
- **x11vnc needs `-noshm`** — the Xvfb display is over TCP, and MIT-SHM fails over TCP.
- **No Wine title bar**: run RIT plain (not `explorer /desktop`, which draws its own
  title bar); `xsetroot -solid '#f0f0f0'` blends the thin uncovered strip.
- **Teardown**: closing RIT's *inner* window exits `Client.exe` but leaves
  `wineserver`/FEX — `run-rit.sh` runs `wineserver -k` after RIT exits, and RITApp's
  `AppDelegate` stops the VM on quit (`RIT_OWN_VM`) so quitting the app kills
  everything. The **raw-VZ** version makes this in-process + crash-proof.

## Remaining (no live Mac needed for code; Mac needed to verify)
1. Verify `build-app.sh` bundle + `RIT.app` double-click on next Mac access.
2. **Orchestration**: have RITApp *start* the VM (it already stops it), so it's fully
   self-contained — bundle `limactl` + `rit.yaml` + `run-rit.sh` in the app.
3. **Raw VZ** (replace Lima): boot the VM in-process via Virtualization.framework
   (durable, no bundled binary, crash-proof teardown). Backup engine: `v2/libkrun/`.
4. Developer ID signing + notarization → `RIT-mac-apple-silicon.dmg`.
