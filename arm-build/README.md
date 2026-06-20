# Native arm64 `http.sys` (Rosetta-free future)

Apple is winding Rosetta 2 down (full support through macOS 27, then games-only).
The long-term Apple-Silicon path is a **native arm64 Wine** with x86 emulation
(FEX) wired into the new WoW64 — no Rosetta. The RIT wildcard fix is a
source-level change, so it ports to arm cleanly; this directory rebuilds the
patched driver for arm targets.

## Outputs

| File | Machine | For |
|---|---|---|
| `out/aarch64/http.sys` | `IMAGE_FILE_MACHINE_ARM64` (0xAA64) | Pure arm64 Linux Wine — Phase 1 validation |
| `out/arm64ec/http.sys` | `IMAGE_FILE_MACHINE_ARM64EC` (0xA641) | CrossOver / Rosetta-free macOS arm64 engine — ship target |

## Build

arm targets need clang (llvm-mingw); gcc-mingw-w64 can't emit arm64/arm64ec PE.
Each arch builds in its own configure — with `arm64ec` in `--enable-archs` the
cross-arch import-lib graph drags the (10.0-broken) arm64ec `winecrt0` into even
the aarch64 target, so they can't share a configure.

```bash
# aarch64 (mature on wine-10.0)
podman build --target export --build-arg ARCH=aarch64 --build-arg WINE_BRANCH=wine-10.0 \
    -o type=local,dest=out-aarch64 .

# arm64ec (needs wine-11.0 — 10.0's winnt.h misroutes x86 asm into the EC compile)
podman build --target export --build-arg ARCH=arm64ec --build-arg WINE_BRANCH=wine-11.0 \
    -o type=local,dest=out-arm64ec .
```

## Why wine-11.0 for arm64ec

On `wine-10.0`, building any arm64ec module fails in `dlls/winecrt0`:
`include/winnt.h` routes x86 inline asm (`int $0x29`, `lock; xchgl`, `"c"`
constraint) into the arm64ec compile. Fixed in the 11.x line.

## Validation (aarch64, done here without booting Wine)

Disassembling `out/aarch64/http.sys` at `url_matches` shows the patch compiled in:

```asm
ldrb  w8, [x25, #0x7]!   ; url->url[7]
and   w8, w8, #0xfe      ; clear low bit   <- only the '+'||'*' patch emits this
cmp   w8, #0x2a          ; 0x2a='*', 0x2b='+' differ only in the low bit
b.eq  ...                ; both now match in one compare
```

Stock Wine is a bare `cmp w8, #0x2b` with no mask. The `and #0xfe` proves the
wildcard fix is in the native arm64 binary.

## Phase 2 (on an Apple Silicon Mac)

CrossOver's bottle ships its own arm64ec `http.sys`; replace it with
`out/arm64ec/http.sys`, then run RIT and confirm `http://localhost:9999/v1/...`
responds. ABI-matching to CrossOver's exact Wine version is the only open
variable; the driver's host_matches ABI has been stable since Wine 5.
