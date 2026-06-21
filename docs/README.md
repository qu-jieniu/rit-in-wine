# Download landing page (GitHub Pages)

`index.html` detects the visitor's OS + Mac chip and offers the right build:

| Detected | Offers | Release asset |
|---|---|---|
| Linux x86_64 | AppImage (stock Wine 11, native) | `RIT-x86_64.AppImage` |
| Linux arm64 | AppImage (stock Wine 11 + FEX) | `RIT-aarch64.AppImage` |
| Intel Mac | `.pkg` (stock Wine 11, native x86) | `RIT-mac-intel.pkg` |
| Apple Silicon | `.pkg` (stock Wine 11 + FEX, Rosetta-free, v2) | `RIT-mac-apple-silicon.pkg` |
| Windows | link to Rotman (RIT is native there) | — |

The clean 2×2: emulation (FEX) appears wherever the chip is arm64 and the app is
x86; native everywhere else. Arch detection is best-effort (UA string for Linux,
WebGL renderer for Mac); the page always shows all options with a fallback hint.

## Enable
Repo **Settings → Pages → Source: Deploy from a branch → `main` / `/docs`**.
The page goes live at `https://qu-jieniu.github.io/rit-in-wine/`.

## macOS version requirement (two layers)

Apple Silicon (v2/libkrun) needs **macOS 14+**; Intel needs **macOS 11+**.

- **Landing page (best-effort warning):** browsers freeze the macOS version in the
  UA string (Safari reports `10.15.7`), so the page only warns when `userAgentData`
  (Chromium) gives the *real* version — avoiding false alarms for everyone else.
  Otherwise it just shows the requirement on each card.
- **The real gate (reliable — the OS knows its own version):**
  - `.pkg`: in the distribution XML add
    `<allowed-os-versions><os-version min="14.0"/></allowed-os-versions>` → Installer
    refuses on older macOS with a clear message.
  - `.app`: set `LSMinimumSystemVersion = 14.0` in `Info.plist` → Finder/Gatekeeper
    blocks launch with "requires macOS 14 or later". Optionally a runtime
    `ProcessInfo.operatingSystemVersion` check shows a friendly dialog.

## How the downloads stay current
The buttons point at `releases/latest/download/<asset>` — so whatever the build
workflows attach to the newest GitHub Release is what users get. The three
builds must publish assets with exactly these names:
`RIT-x86_64.AppImage`, `RIT-mac-intel.pkg`, `RIT-mac-apple-silicon.pkg`.
