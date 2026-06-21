# v2 slim payload — Xvnc display + stripped

The payload for the native `RIT.app`: stock Wine 11 + RIT, the **slimmest display**
(one `Xvnc` process; no Xvfb/x11vnc/noVNC/websockify/WM), and a safe cruft strip.

## Size — verified

| | compressed (zstd -19) |
|---|---|
| noVNC payload (`v2/Dockerfile.payload`) | ~1.3 GB |
| **slim Xvnc + cruft strip (this)** | **881 MB** ✅ RIT verified (API + VNC) |

That hits the ~700–900 MB target. RIT confirmed working after the strip: API binds
`:9999` (~10 s) and Xvnc answers the `RFB 003.008` handshake on `:5900`.

## What is / isn't strippable

- ✅ Stripped: winetricks cache, apt lists/cache, docs/man/info, non-en locales,
  and the whole noVNC/web display stack (→ single `Xvnc`).
- ❌ **Not** strippable: the 64-bit Wine dirs. Even a `win32` prefix runs under
  **new-WoW64** (32-bit Windows code in a 64-bit unix process), so
  `x86_64-unix` + the wow64 parts of `x86_64-windows` are required. Removing them
  breaks RIT (verified).

A smaller image would need a **minimal-base rebuild** (`winehq --no-install-recommends`
+ only the libs Wine actually dlopens) to avoid the recommends bloat — higher
risk, separate effort. 881 MB is a good landing point.

## Build + ship

```bash
podman build -f v2/slim/Dockerfile -t rit-v2-slim v2/slim      # FROM rit-prefix:installed
# the shippable payload is the flattened, compressed rootfs:
podman export $(podman create rit-v2-slim) | zstd -19 -T0 > rit-payload.tar.zst   # ~881 MB
```

The macOS wrapper bundles (or first-run-downloads) `rit-payload.tar.zst`, expands
it, and boots it in the libkrun microVM (FEX inside on Apple Silicon).
