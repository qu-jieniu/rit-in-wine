# v2 — Rosetta-free RIT (Wine 11 + FEX), packaged for macOS

The durable, patch-free successor to the GPTK/Rosetta `.pkg` (v1). Depends on
neither Rosetta nor an off-label tool, and aims for zero student setup once the
macOS wrapper is built.

## Architecture

```
RIT.app (native Swift wrapper)
 └─ Apple Containerization framework (macOS 26+)  — OR libkrun (macOS 11+)
     └─ lightweight arm64 Linux microVM
         └─ this payload image (amd64) run via FEX   ← Rosetta-free x86
             ├─ stock Wine 11   (NO http.sys patch — fix is upstream)
             ├─ win32 prefix + .NET 4.8 + RIT (MSI 1.8.464)
             └─ noVNC web desktop  (Xvfb + openbox + x11vnc + websockify)
 └─ shows the noVNC desktop in a native window; student never sees a container
```

## The payload (this directory) — verified on Linux

`Dockerfile.payload` + `rit-desktop.sh` build an amd64 image that:
- runs RIT on **stock Wine 11** (no patch),
- serves the **REST API on :9999** (verified: HTTP 401),
- serves the **GUI as a web desktop on :6080** (noVNC, verified: HTTP 200).

It runs natively on x86 and, unchanged, under FEX inside an arm64 microVM. The
hard parts (FEX runs RIT; API responds; display works) are all proven.

```bash
podman build -f v2/Dockerfile.payload -t rit-v2-payload v2     # FROM rit-prefix:installed
podman run --rm -p 6080:6080 -p 9999:9999 --shm-size=1g rit-v2-payload
#   desktop -> http://localhost:6080/vnc.html      API -> http://localhost:9999/v1/
```

## Remaining (needs a Mac to build)

The Swift wrapper using Apple's `Containerization` framework (or libkrun) to boot
the microVM, run this payload under FEX, and show the noVNC view in a window.
macOS 26+ for Containerization; libkrun if older-macOS support is wanted.
