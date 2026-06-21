# Apple-Silicon validation via Lima (throwaway test, not the shipped app)

Boots arm64 Linux on your Mac through **Apple's Virtualization.framework** (the same
engine the real `RIT.app` will use) and runs **FEX + Wine + RIT** inside it — the
proven green-CI recipe, on your hardware. A green result here de-risks the whole
Apple-Silicon approach before any Swift app is written.

## What it proves
- VZ boots arm64 Linux on your Mac ✓
- FEX runs the x86 Wine/RIT (Rosetta-free) ✓
- **RIT's API reaches the Mac's `localhost:9999`** (for Python/R) ✓
- **RIT's GUI shows** via VNC on `localhost:5900` ✓

## Steps

**0. Publish the payload once (from any machine / CI):**
Run the **Publish RIT payload (GHCR)** workflow (Actions tab → Run workflow), then
make the `rit-payload` package **public** (repo → Packages → Settings → visibility).

**On your Mac:**
```bash
brew install lima
cd <this repo>
limactl start v2/macos/lima/rit.yaml          # boots arm64 Ubuntu + installs FEX (~few min)
limactl shell rit bash v2/macos/lima/run-rit.sh   # first run pulls payload + sets up FEX, then starts RIT
```

`run-rit.sh` prints `>>> RIT API listening on :9999` when RIT is up. Then, on the Mac:
```bash
curl http://localhost:9999/v1/case      # expect HTTP 401 (RIT's API answering)
open vnc://localhost:5900               # macOS Screen Sharing -> RIT's window
```

## Notes
- First launch is slow: FEX JIT-translating the .NET startup is heavy. Give it a
  couple of minutes; the script waits up to 10.
- The payload is **amd64**; FEX runs it on the arm64 VM. The Xvfb/x11vnc display is
  driven from the **arm64 host side** (the x86 Xvfb inside the payload won't run
  under FEX) — the same approach as the green CI.
- This is **validation only**. The shipped `RIT.app` replaces Lima with a small
  VZ-based Swift wrapper and the VNC view embedded in the window.

## If green
Report back and I'll build the real VZ `RIT.app` (Swift), and — if the macOS floor
holds — drop the version gate from 14 → 13.
