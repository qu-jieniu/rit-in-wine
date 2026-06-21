# RIT Server (Instructor Application) — deployment analysis

Source: `RIT Instructor Application-1.8.464.msi` (22.8 MB, from
`https://rit.306w.ca/release/1.8.464/`). Main binary: `Server.exe` (.NET).
Findings from extracting the MSI + decompiling `Server.exe` (analysis only — the
MSI/decompiled payload is gitignored).

## TL;DR
- **Runtime is identical to the client** → reuse our Wine 11 + .NET 4.8 deployment.
  No new runtime work; just install the Instructor MSI into the same kind of prefix.
- **The one hard extra is a Rotman license** — online-validated; the server won't
  run cases without it.

## Runtime (good news — same as the client)
- **.NET Framework 4.8**, 32-bit PE, WinForms GUI.
- REST API via **`HttpListener`** (registers a URL ACL, `http add urlacl`) — same
  http.sys path as the client, which Wine 11 handles natively.
- ⇒ Runs on the **same Wine 11 + .NET 4.8 prefix** we built for the client, with a
  display (X / VNC). Can be packaged the same ways (container / AppImage / Mac app).

## Ports
| Port | Purpose |
|---|---|
| **10000** TCP | clients connect here (`ServerPort`) |
| **10002** | the server's own REST API (`APIPort`, `HttpListener`, routes like `GET /v1/case`) |
| TeamSpeak (optional) | embedded **TeamSpeak SDK server** for voice (only if voice is used) |

## The license gate (the "extra")
- Settings: `LicenseName`, `LicenseKey`, `LicenseString` (empty by default).
- `Server.License.IsValid()` gates startup; `License.IsCaseAllowed(PresetName)`
  gates **which cases** may run. Failure → "Invalid or expired license".
- **Online validation** (`licenseManager.ValidateKey(Name, Key)`) with a cached
  **offline grace period**: "Your local license expires on {date}. Please connect
  to the internet before then…" (Offline Mode).
- ⇒ You **must obtain a valid license (Name + Key) from Rotman** (instructor
  licensing). This is a licensing requirement, not an engineering one.

## Other deployment facts
- **File-based storage** — saves reports/state to directories; **no database**.
- **Case files** loaded by the instructor (downloadable from
  `rit.306w.ca/release/<version>/`); version must match the server.
- **CommandLine options** exist (`Server(CommandLineOptions)`) — some automation
  (e.g. auto-load) may be possible for headless-ish operation, though it's a GUI app.
- AWS CloudWatch logging (telemetry — can be firewalled/ignored).

## Deploy checklist
1. Wine 11 + .NET 4.8 prefix (reuse the client's) + `wine msiexec /i "RIT Instructor Application-….msi" /qn`.
2. A display (X / VNC) — it's a GUI instructor app.
3. **A valid Rotman license** entered in Settings (Name + Key) — *required*.
4. Open `:10000` (clients) and `:10002` (if using the server API) on the host.
5. Load the case file(s) for your course.
