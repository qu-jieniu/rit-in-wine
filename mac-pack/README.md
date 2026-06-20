# Shipping RIT for Apple Silicon Macs

This directory is everything you need to produce a distributable `RIT.app` /
`RIT.dmg` for Mac users.

## What's in here

| File | What it is | Built on |
|---|---|---|
| `http.sys` | Patched Wine HTTP driver (PE32+, x86_64), 265 KB | Linux |
| `wine-host-matches-star-wildcard.patch` | One-line Wine source patch (for upstreaming) | Linux |
| `build-rit-app.sh` | Mac-side script that produces `RIT.app` + `RIT.dmg` | runs on macOS |
| `README.md` | This file | — |

## Why a patched http.sys is needed

RIT's local REST API on `localhost:9999` is implemented with .NET
`HttpListener`. The client registers `http://*:9999/v1/` when it detects admin
(it always does under Wine). Stock Wine 10 only treats `+` as a wildcard host
in its `dlls/http.sys/http.c::host_matches`, so `*`-prefixed registrations
match no incoming Host header. Requests get accepted by the driver and queue
forever waiting for user-mode to drain them. This is the "I could never get
the API working" symptom Mac users have hit for years.

The patch is a one-character change extending the wildcard branch to also
match `*`. See `wine-host-matches-star-wildcard.patch`.

The compiled output is a Windows PE file — it runs unmodified inside any
reasonably current Wine engine on macOS (gcenx wine-crossover, Whisky's GPTK
wine, CrossOver bottles, WineskinServer's WS11 engines).

## Mac build steps (~10 min wall clock, mostly winetricks dotnet48)

```bash
# 1. Install Wineskin (one time)
brew install --cask --no-quarantine gcenx/wine/wineskin

# 2. Build
cd mac-pack
./build-rit-app.sh

# Outputs: out/RIT.app and out/RIT.dmg
```

Optional: set `CODESIGN_IDENTITY` and `NOTARY_PROFILE` in the env to get a
signed + notarized DMG that won't get Gatekeeper-flagged on M-chip Macs.

## Distribution

Drop `RIT.dmg` on Dropbox / S3 / wherever, link from the project README. End
users:

1. Download DMG
2. Drag `RIT.app` into `/Applications`
3. Double-click. RIT launches, ClickOnce installer runs, login screen appears.
4. Their local REST API on `http://localhost:9999/v1/...` works out of the box.

## Gatekeeper / signing

Three modes the build script supports, in order of user-friendliness:

| Mode | How to enable | What users see |
|---|---|---|
| **Apple Developer ID + notarize** | `export CODESIGN_IDENTITY="Developer ID Application: …"` and `export NOTARY_PROFILE=…` before `./build-rit-app.sh` | Double-click works, no warnings |
| **Ad-hoc sign** (default if no env vars) | nothing | Gatekeeper "unidentified developer" prompt — user must right-click → Open OR run `xattr -dr com.apple.quarantine /Applications/RIT.app` |
| **Unsigned** | `export SKIP_CODESIGN=1` | Same prompt as ad-hoc, plus "app is damaged" possible on tampered bundles |

There is no way to bypass Gatekeeper without an Apple-issued Developer ID cert
($99/yr). Self-signed or homebrew CA certs do **not** establish trust.

If you don't want to pay Apple, keep the `xattr -dr com.apple.quarantine`
instruction in the project README (same as your current Method 2).

## Clean exit

The build script enables Wineskin's "Quit Wrapper Mode" (Wineskin watches the
RIT process and tears the bottle down when it exits) and registers a
`wineserver -k` post-run hook as a backstop. Without these, Wine background
processes (`wineserver`, `winedevice.exe`, `services.exe`, `rpcss.exe`,
`plugplay.exe`, the http.sys driver host) keep running after the user closes
RIT — Dock icon stays bouncing, `top` shows them eating CPU forever.

## Rebuilding `http.sys` for a different Wine version

If the bundled WineskinServer engine ever moves to a Wine major version where
`dlls/http.sys/` ABI changed (unlikely — it's been stable since Wine 5), you
need to rebuild `http.sys` against that Wine source:

```bash
# On any Linux box
git clone --depth 1 --branch wine-X.Y https://gitlab.winehq.org/wine/wine.git
cd wine
git apply /path/to/wine-host-matches-star-wildcard.patch
./configure --without-x --without-freetype --disable-tests
make -j dlls/http.sys/x86_64-windows/http.sys
# Resulting binary at dlls/http.sys/x86_64-windows/http.sys
```

(The `wine-build/Dockerfile` in the parent directory automates this on Linux.)

## Long-term

The minimal patch is small enough to submit upstream — once accepted, future
Wine releases on macOS will work out of the box without any bottle surgery.
