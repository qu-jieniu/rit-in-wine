# RIT packaging pipeline (validated, no CrossOver)

The end-to-end pipeline that produces a small, reproducible RIT bottle on **stock
upstream Wine 11** — no CrossOver, no patch, no Rosetta. Every step below was run
and the RIT REST API confirmed responding after it.

## Proven end-to-end

Real RIT (`Client.exe`, 32-bit i386) installed from its MSI on stock Wine 11 +
.NET 4.8, launched headless, REST API bound `:9999` and answered `HTTP 401` in
0.22 s (correct unauth response — the point is it *responds* instead of hanging).

## The pipeline

| Stage | File | Output |
|---|---|---|
| 1. Bake prefix | `Dockerfile.prefix` + `bake-prefix.sh` | Wine 11 prefix with .NET 4.8 (`ARG WINEARCH=win32` for 32-bit RIT) |
| 2. Install RIT | `rit-install-test.sh` | pinned MSI via `wine msiexec /i … /qn`; launch + API smoke |
| 3. Slim | `Dockerfile.slim` + `strip-prefix.sh` | drops ngen images + unused D3D/Vulkan/media DLLs |
| 4. Ship | `tar … | zstd -19` | compressed prefix; pair with a macOS Wine engine |

Key fixes baked in:
- **Mono/Gecko disabled during init** (`WINEDLLOVERRIDES=mscoree=d;mshtml=d`) so a
  fresh prefix doesn't hang on the headless "install Wine Mono?" dialog — the
  classic fresh-prefix failure.
- **MSI install only succeeds on a settled .NET 4.8 prefix**; bake .NET first.

## Size (the ≤500 MB target)

| Prefix variant | Raw | Compressed (zstd -19) | RIT API |
|---|---|---|---|
| win64 unstripped | 2305 MB | 482 MB | PASS |
| win64 stripped | 1729 MB | 378 MB | PASS |
| **win32 stripped** | 978 MB | **225 MB** | PASS |

Total Mac package ≈ **225 MB prefix + ~150 MB Wine engine ≈ ~375 MB** — under target.

RIT is 32-bit, so the `win32` prefix sheds the entire 64-bit Wine DLL set. Caveat:
a pure win32 prefix needs a 32-bit-capable Wine engine (fine on current
gcenx/CrossOver engines and under FEX; upstream Wine trends toward wow64-only —
a far-future watch item).

## Reproduce

```bash
cd test
podman build -f Dockerfile.prefix --build-arg WINEARCH=win32 -t rit-prefix:dotnet48-win32 .
podman build -f Dockerfile.slim   --build-arg BASE=rit-prefix:dotnet48-win32 -t rit-prefix:slim-win32 .
podman run --rm --security-opt seccomp=unconfined --shm-size=1g rit-prefix:slim-win32   # API smoke -> PASS
podman run --rm --entrypoint tar rit-prefix:slim-win32 -C /opt -cf - rit-prefix | zstd -19 -T0 > rit-prefix.tar.zst
```
