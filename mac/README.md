# Intel Mac build — native stock Wine `.app` (`.dmg`)

For **Intel Macs**: RIT runs in **native x86_64 Wine** — no Rosetta (Intel *is*
x86), no VM, no FEX. Ships as `RIT-mac-intel.dmg` (drag `RIT.app` → Applications).

(Apple Silicon uses the v2 microVM instead — see `v2/macos/`. Intel doesn't need
a VM because it runs x86 natively.)

## Multi-process teardown (the hardened launcher)

`RITLauncher.m` is the old `launcher.m` fixed for the two gaps it had:

| Case | Handling |
|---|---|
| Graceful quit (⌘Q / close / Wine exits) | kill the Wine **process group** + **`wineserver -k`** |
| **Force Quit / `kill -9`** of the launcher | a **`kqueue` watchdog** (own session, survives the launcher) fires on `NOTE_EXIT` and runs the same teardown |

Why both: Wine's `wineserver` + services (`services.exe`, `plugplay`, `winedevice`,
`explorer`) `setsid()` away, so a group-kill alone misses them — `wineserver -k` is
the catch-all. SIGKILL is uncatchable, so only an out-of-session watchdog can
guarantee teardown on Force Quit. The watchdog **self-terminates** right after; it
is not a lingering daemon. Net: **killing RIT — however — kills everything.**

## Engine: stock Wine, vendored (not gcenx)

`WINE_TARBALL` is **upstream Wine 11 built from source** for macOS x86_64 in CI, so
nothing third-party can disappear. The win32 prefix (`PREFIX_TAR`) is the same
`.NET 4.8 + RIT MSI` prefix the other builds use (exported from `rit-prefix:installed`).

## Build (on `macos-13`, Intel runner)

```bash
WINE_TARBALL=stock-wine-11-osx-x86_64.tar.xz \
PREFIX_TAR=rit-prefix-win32.tar.zst \
SIGN_ID="Developer ID Application: …" \
  mac/build-intel-app.sh
# -> mac/build/RIT-mac-intel.dmg   (then notarytool submit + stapler staple)
```

OS gate: `Info.plist` `LSMinimumSystemVersion = 11.0` → Finder refuses to launch on
older macOS with a clear message.
