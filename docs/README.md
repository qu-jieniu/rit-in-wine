# Download landing page (GitHub Pages)

`index.html` detects the visitor's OS + Mac chip and offers the right build:

| Detected | Offers | Release asset |
|---|---|---|
| Linux | AppImage | `RIT-x86_64.AppImage` |
| Intel Mac | `.pkg` (stock Wine 11, native x86) | `RIT-mac-intel.pkg` |
| Apple Silicon | `.pkg` (stock Wine 11 + FEX, Rosetta-free, v2) | `RIT-mac-apple-silicon.pkg` |
| Windows | link to Rotman (RIT is native there) | — |

Mac-chip detection is best-effort (WebGL renderer); the page always shows all
options and an "About This Mac" hint as a fallback.

## Enable
Repo **Settings → Pages → Source: Deploy from a branch → `main` / `/docs`**.
The page goes live at `https://qu-jieniu.github.io/rit-in-wine/`.

## How the downloads stay current
The buttons point at `releases/latest/download/<asset>` — so whatever the build
workflows attach to the newest GitHub Release is what users get. The three
builds must publish assets with exactly these names:
`RIT-x86_64.AppImage`, `RIT-mac-intel.pkg`, `RIT-mac-apple-silicon.pkg`.
