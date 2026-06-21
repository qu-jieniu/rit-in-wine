# v2 minimal payload — 631 MB (the recommended payload)

The smallest verified RIT payload: **debian-slim + winehq Wine 11
(`--no-install-recommends`)** + only the X/font libs Wine actually needs + the
baked win32 prefix + the slim `Xvnc` display. Supersedes `v2/slim` (it *is* the
slim display on a minimal base).

## Size — verified

| Payload | Compressed (zstd --ultra -22) |
|---|---|
| noVNC (`v2/Dockerfile.payload`) | ~1.3 GB |
| slim Xvnc + cruft strip | 805 MB |
| **minimal base + slim display (this)** | **631 MB** ✅ |

Raw image 3.46 GB vs the slim 5.13 GB — dropping winehq's `--install-recommends`
bloat (gstreamer/mesa/cups) is the lever.

## Verified working

- RIT API binds `:9999` (~15 s)
- `Xvnc` answers the `RFB 003.008` handshake on `:5900`
- **GUI initialized** — API stays bound and the log has no `nodrv_CreateWindow` /
  `winex11` / font / unhandled-exception errors (a WinForms app that couldn't
  create its window would crash and drop the API). So `--no-install-recommends`
  did not break the display — the explicit X/font libs cover what Wine dlopens.

## Build + ship

```bash
podman build -f v2/minimal/Dockerfile -t rit-v2-min v2/minimal   # needs rit-prefix:installed (the baked prefix)
podman export $(podman create rit-v2-min) | zstd --ultra -22 -T0 > rit-payload.tar.zst   # ~631 MB
```

The macOS wrapper bundles (or first-run-downloads) `rit-payload.tar.zst`, expands
it, and boots it in the libkrun microVM (FEX inside on Apple Silicon; the native
RIT.app shows the `:5900` VNC in a window).

## Total v2 app
~631 MB payload + ~tens of MB libkrun (or 0 with Apple Containerization) +
a few-MB Swift wrapper ≈ **~650 MB** — smaller than v1's GPTK .pkg.
