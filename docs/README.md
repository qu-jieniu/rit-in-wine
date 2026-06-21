# Download landing page (GitHub Pages)

Styled like a **Quarto** site — Bootstrap 5 + the `cosmo` Bootswatch theme (the
same stack Quarto's default HTML output uses), loaded from CDN so it deploys on
`/docs` with no build step. (Quarto itself isn't required; if you'd rather author
it as a real `index.qmd` and render with `quarto render`, the markup ports over
directly — ask and I'll generate the `.qmd` + a render workflow.)

`index.html` detects the visitor's OS + Mac chip and offers the right build:

| Detected | Offers | Release asset |
|---|---|---|
| Linux x86_64 | AppImage (stock Wine 11, native) | `RIT-x86_64.AppImage` |
| Linux arm64 | AppImage (stock Wine 11 + FEX) | `RIT-aarch64.AppImage` |
| Intel Mac | `.dmg` drag-install (stock Wine 11, native x86) | `RIT-mac-intel.dmg` |
| Apple Silicon | `.dmg` drag-install (stock Wine 11 + FEX, Rosetta-free, v2) | `RIT-mac-apple-silicon.dmg` |
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
- **The real gate (reliable — the OS knows its own version):** since the Mac
  builds ship as a `.dmg` containing a drag-install `.app`, set
  `LSMinimumSystemVersion = 14.0` (Apple Silicon) / `11.0` (Intel) in the app's
  `Info.plist` → Finder/Gatekeeper refuses to launch on older macOS with
  "requires macOS 14 or later". Optionally a runtime
  `ProcessInfo.operatingSystemVersion` check shows a friendly dialog.

## How the downloads stay current
The buttons point at `releases/latest/download/<asset>` — so whatever the build
workflows attach to the newest GitHub Release is what users get. The four
builds must publish assets with exactly these names:
`RIT-x86_64.AppImage`, `RIT-aarch64.AppImage`, `RIT-mac-intel.dmg`,
`RIT-mac-apple-silicon.dmg`.
