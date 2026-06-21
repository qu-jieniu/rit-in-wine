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

### Fix for v2
Use a **block-device rootfs** instead of virtiofs: build an ext4 image from the
payload and attach it with `krun_add_disk(ctx, "root", "rit.img", false)` — block
I/O is far faster than virtiofs for this access pattern. (Also bump vCPUs/RAM.)
That's the next iteration before the macOS wrapper.

## Maps to the macOS wrapper

```
RIT.app (Swift)
 └─ this launcher logic (libkrun, HVF backend on macOS 14+)
     └─ arm64 microVM
         └─ payload (amd64) under FEX   ← Rosetta-free
 └─ WKWebView on the mapped noVNC port -> RIT in a native window
```
