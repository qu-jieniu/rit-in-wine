# RIT Linux AppImage

Self-contained `RIT.AppImage` = bundled Wine + the RIT-baked win32 prefix + an
`AppRun` launcher (same single-master / `wineserver -k` teardown as the Mac one).

## Status

- ✅ Builds: `RIT-x86_64.AppImage`, ~369 MB (under the 500 MB target).
- ✅ Wine boots and RIT starts; prefix expands to `~/.local/share/RIT` on first
  run; clean teardown on exit.
- ⚠️ On a *pristine* 64-bit-only host the bundled Wine doesn't yet relocate its
  unix X11 driver / resolve every `dlopen`'d 32-bit lib. RIT is 32-bit, so the
  host also needs `libc6:i386` / `glibc.i686`.

## Completing portability (recommended)

Hand-bundling winehq + every `dlopen`'d lib is whack-a-mole. Instead, base the
AppImage on a **known-portable Wine build**:

- **Kron4ek static Wine** (`wine-*-amd64-wow64` / multilib tarballs) — built to
  run relocated, with the unix drivers and lib set already sorted. Drop our
  prefix + `AppRun` on top.
- or **linuxdeploy** with a Wine-aware step to gather deps automatically.

The prefix, `AppRun`, icon, and `.desktop` here are reusable as-is; only the
Wine-engine bundling stage (`build-appimage.sh` steps 1 + the dlopen-lib list)
gets replaced by extracting a portable Wine tarball into `usr/`.

## Build

```bash
podman build -f test/Dockerfile.prefix  --build-arg WINEARCH=win32 -t rit-prefix:dotnet48-win32 test
podman build -f test/Dockerfile.slim    --build-arg BASE=rit-prefix:dotnet48-win32 -t rit-prefix:slim-win32 test
podman build -f test/Dockerfile.installed -t rit-prefix:installed test
podman build -f appimage/Dockerfile.appimage -t rit-appimage-builder appimage
podman run --rm --privileged -v "$PWD/appimage/out:/out" rit-appimage-builder
# -> appimage/out/RIT-x86_64.AppImage
```
