# Parked workflows (do NOT run)

GitHub only executes workflows located *directly* in `.github/workflows/`.
Files here are parked — kept in the repo but inert — during the FEX /
Rosetta-free transition. Move one back to `.github/workflows/` to re-enable.

- `build-mac.yml` / `build-mac-engine.yml` — GPTK (Rosetta) Mac .pkg + engine build
- `auto-mirror-engine.yml` / `auto-mirror-clientapp.yml` — version mirrors
- `release-on-tag.yml` — release on `v*` tag
- `debug-mac.yml` — tmate debug session

Active in `.github/workflows/`: test-httpsys, test-rit-version, validate-fex-arm64.
