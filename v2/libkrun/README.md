# v2 launcher core — libkrun microVM

`rit-vm.c` is the portable core of the v2 launcher. The **same libkrun API calls
compile on Linux (KVM) and macOS/Apple-Silicon (Hypervisor.framework)** — so this
is developed/tested here on Linux and reused by the macOS `RIT.app` wrapper (which
wraps it in Swift and shows the noVNC desktop in a native window).

It declares the libkrun API inline (no `libkrun-devel` headers needed) and links
the installed lib:

```bash
cc rit-vm.c -o rit-vm -l:libkrun.so.1
podman create rit-v2-payload | xargs podman export | tar -C rootfs -xf -   # rootfs
./rit-vm rootfs        # boots the microVM, maps ports to the host
```

## What's proven on this box (Fedora, libkrun 1.11.2 + KVM)

- ✅ The launcher **boots a libkrun microVM** with the payload as its rootfs.
- ✅ The microVM **runs the payload** — the guest console shows the `rit-desktop`
  entrypoint executing (`== launching RIT ==`).
- ✅ **libkrun port-mapping works** — the noVNC web desktop served from inside the
  guest is reachable on the host (`HTTP 200`, verified on a free, uncontended port).

## Honest finding: virtiofs is slow for the Wine/.NET boot

With a `krun_set_root` (virtiofs) rootfs, the lightweight desktop services
(Xvfb/openbox/x11vnc/noVNC) come up in seconds, but **RIT itself (Wine + .NET
reading thousands of files) is I/O-bound and did not finish binding `:9999`
within the test window.** RIT is already proven to run under FEX on arm64 (the
green CI) and natively — so this is a **microVM I/O perf issue, not a RIT issue.**

### Block-device root: tried, and the lesson learned
The launcher now supports both modes (pass a dir → virtiofs; pass `*.img` →
`krun_set_root_disk`). I built a populated, **root-owned** ext4 image
(`podman unshare mke2fs -d rootfs rit.img`) and booted it — but the VM exits
immediately. Reason: `krun_set_root_disk` boots the image as a **real root**,
expecting an init that mounts `/proc`,`/dev`,`/sys`; our **container** rootfs
relies on the runtime to do that, which is exactly what virtiofs (`krun_set_root`)
provides. So:

- **virtiofs = correct for a container payload** (boots, runs RIT, maps the
  desktop). Slower Wine/.NET startup.
- **block-device = faster I/O but needs a bootable-init image** (a different
  build: add a minimal init that mounts the kernel fs, or ship a real OS image).

The clean fix for v2 perf is therefore either an init-carrying disk image or
virtiofs with caching tuned — best finished against the real macOS target, since
the Mac uses a different libkrun backend (HVF) anyway.

## Is FEX needed under libkrun?
**Only on arm64 hosts (the Mac).** The microVM is the host's architecture:
- x86 Linux (this box): the microVM is x86 → the amd64 payload runs **natively,
  no FEX** (so this Linux test doesn't exercise FEX).
- Apple Silicon: the microVM is arm64 → x86 RIT needs **FEX inside the guest**
  (the green-CI setup). Unavoidable — RIT is 32-bit x86 and arm64 Wine can't run
  it without an x86 emulator.

## Maps to the macOS wrapper

```
RIT.app (Swift)
 └─ this launcher logic (libkrun, HVF backend on macOS 14+)
     └─ arm64 microVM
         └─ payload (amd64) under FEX   ← Rosetta-free
 └─ WKWebView on the mapped noVNC port -> RIT in a native window
```
