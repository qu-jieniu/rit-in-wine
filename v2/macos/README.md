# RIT.app (v2) — macOS wrapper (skeleton)

Native `RIT.app` that boots the v2 payload in a **libkrun microVM** and shows
RIT's window via a **native VNC view** (no browser). The student double-clicks;
the microVM + FEX + Wine are invisible. **Compiles on a Mac only** — this is the
remaining v2 piece; the rest (payload, libkrun launcher, FEX-runs-RIT) is proven.

## Architecture

```
RIT.app  (Swift, signed w/ RIT.entitlements: hypervisor + JIT)
 ├─ RitVM (main.swift)  — libkrun boot (SAME C API as v2/libkrun/rit-vm.c)
 │   └─ arm64 microVM (Hypervisor.framework, macOS 14+)
 │       └─ payload (amd64) — FEX runs the x86 Wine/RIT  ← Rosetta-free
 │           ├─ stock Wine 11 + RIT (MSI 1.8.464)
 │           ├─ x11vnc on :5900   (the display)
 │           └─ RIT REST API on :9999
 └─ VNCView (NSViewRepresentable) — native VNC client on 127.0.0.1:5900
     -> RIT shown in a normal Mac window
```

## What's done vs TODO

Done (proven elsewhere in this repo):
- payload image (`v2/Dockerfile.payload`) — RIT on stock Wine 11 + VNC + API
- libkrun boot path (`v2/libkrun/rit-vm.c`) — microVM boots, runs payload, maps ports
- FEX runs RIT on arm64 (green CI `validate-fex-arm64.yml`)
- entitlements (`RIT.entitlements`) — hypervisor + JIT for FEX

TODO (Mac-side, marked in `main.swift`):
1. **GUI display** — MVP: open macOS Screen Sharing (`vnc://localhost:5900`), no library. Polish: embed RoyalVNC (optional). The API (:9999) is forwarded regardless — Python/R hit localhost:9999 unchanged.
2. **Payload packaging** — `PayloadSetup.ensureRootfs()`: ship the slimmed payload
   rootfs in `Resources/` (or pull on first run) and expand it once to
   `~/Library/Application Support/RIT/rootfs`.
3. **FEX in the guest** — the payload must carry FEX so the arm64 guest runs the
   amd64 RIT (the green-CI setup baked into the image), since on Apple Silicon the
   microVM is arm64.
4. **Perf** — virtiofs is slow for Wine/.NET start; tune (caching) or ship a
   bootable-init disk image (see `v2/libkrun/README.md`).
5. **Bundle libkrun** + sign with the entitlements; notarize the `.app`/`.pkg`.

## Build (on macOS 14+, Apple Silicon)

```sh
brew install libkrun        # or MacPorts
swift build -c release      # link libkrun; see Package.swift (TODO)
codesign --options runtime --entitlements RIT.entitlements --sign "Developer ID Application: …" RIT.app
xcrun notarytool submit … && xcrun stapler staple RIT.app
```
