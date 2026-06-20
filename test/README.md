# http.sys API regression test (upstream Wine, no CrossOver)

Proves that RIT's REST API actually works under Wine — directly, without .NET,
winetricks, or CrossOver. RIT registers `http://*:9999/` via .NET
`HttpListener`; the test exercises that exact kernel path with a tiny C program.

## Headline finding

**Upstream Wine 11.0 already serves the API with no patch.** The one-line
`host_matches` `*`-wildcard fix this project carried was **upstreamed** between
Wine 10.0 and 11.0. The patched `http.sys` is therefore only needed for engines
still on Wine ≤10 (e.g. GPTK / Whisky / older CrossOver). On Wine 11+ the driver
is correct out of the box.

## What the test does

`urltest.c` registers `http://*:PORT/` through the HTTP Server API, fires a plain
TCP HTTP request at `127.0.0.1:PORT`, and checks delivery:

- exit 0 (PASS): `HttpReceiveHttpRequest` delivered the request
- exit 1 (FAIL): timed out — the `*`-wildcard host never matched (the old bug)

## Local results (Wine 11.0, amd64)

| Driver | Expected | Result |
|---|---|---|
| Stock upstream Wine 11.0 | PASS | ✅ PASS |
| Patched (wine-11.0 + fix) | PASS | ✅ PASS |
| Buggy control (forced `'+'`-only) | FAIL | ✅ FAIL |

The buggy control failing is what proves the test is meaningful (not a vacuous
always-pass). `http.sys.buggy` is that control, built from wine-11.0 with the
`*` removed (see `arm-build` `--build-arg PATCH=nostar`).

## Run locally

```bash
podman build -f test/Dockerfile.x86_64 -t rit-httptest:x86_64 test
podman run --rm rit-httptest:x86_64 stock     # expect PASS (exit 0)
podman run --rm rit-httptest:x86_64 patched   # expect PASS
podman run --rm -v "$PWD/test/drivers/x86_64/http.sys.buggy:/test/http.sys:ro" \
    rit-httptest:x86_64 patched               # expect FAIL (exit 1)
```

## CI

`.github/workflows/test-httpsys.yml`:
- **x86_64-native** — Wine 11 on amd64; asserts stock PASS, patched PASS, buggy FAIL.
- **arm64-emulated** — the same x86_64 Wine image under x86 emulation on arm64
  hardware (`ubuntu-24.04-arm` + binfmt). This is the Rosetta-free Apple-Silicon
  model: an x86 Windows app on arm64 via an x86 emulator + upstream Wine, no
  CrossOver. (On macOS the emulator is FEX; CI uses qemu-user as the readily
  available stand-in — same architecture.)
