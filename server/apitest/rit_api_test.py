#!/usr/bin/env python3
"""
RIT API test suite — exercises the RIT v1 REST API and asserts response shapes.

Works against ANY live RIT API (same /v1 schema for both):
  - the CLIENT API (default :9999) with the client connected to a live case
    (e.g. flserver.rotman.utoronto.ca) — legitimate with your trader credentials,
  - the SERVER/DMA API (:10002) once your server license is renewed.

Auth is HTTP Basic: base64("TraderID:Password"), per the server (ApiAuthorizationToken).
Data endpoints require a RUNNING simulation; with no case they return 401
"Simulation must be running" — the suite reports that distinctly (not a failure of
the API, just no live case).

Usage:
  RIT_API=http://localhost:9999 RIT_USER=trader1 RIT_PASS=password ./rit_api_test.py
  (no creds -> only unauth/plumbing checks)
"""
import base64, json, os, sys, urllib.request, urllib.error

BASE = os.environ.get("RIT_API", "http://localhost:9999").rstrip("/")
USER = os.environ.get("RIT_USER", "")
PASS = os.environ.get("RIT_PASS", "")
AUTH = base64.b64encode(f"{USER}:{PASS}".encode()).decode() if USER else None

# endpoint -> required fields we assert when a case is running
SCHEMAS = {
    "/v1/case":            ["name", "period", "tick", "ticks_per_period", "total_periods", "status"],
    "/v1/trader":          ["trader_id", "first_name", "last_name", "nlv"],
    "/v1/limits":          [],
    "/v1/news":            [],
    "/v1/securities":      ["ticker"],          # list[obj]; assert on first element
    "/v1/securities/book": [],                  # needs ?ticker=
    "/v1/assets":          [],
    "/v1/orders":          [],
    "/v1/tenders":         [],
}

def call(path, auth=AUTH):
    req = urllib.request.Request(BASE + path)
    if auth:
        req.add_header("Authorization", auth)   # RIT also accepts the bare base64 token
    try:
        with urllib.request.urlopen(req, timeout=8) as r:
            return r.status, r.read().decode(errors="replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode(errors="replace")
    except Exception as e:
        return None, str(e)

def check(name, cond, detail=""):
    print(f"  [{'PASS' if cond else 'FAIL'}] {name}" + (f" — {detail}" if detail else ""))
    return cond

def main():
    print(f"== RIT API test suite -> {BASE} (user={USER or '(none)'}) ==")
    ok = True

    # 1. plumbing + auth (no license/case needed)
    code, body = call("/v1/case", auth=None)
    ok &= check("unauth /v1/case returns 401", code == 401, f"got {code}")

    if not AUTH:
        print("  (no creds set — skipping authenticated checks)")
        return 0 if ok else 1

    # 2. authenticated endpoints
    code, body = call("/v1/case")
    running = False
    if code == 401 and "running" in body.lower():
        print("  [INFO] authenticated, but no case running ('Simulation must be running').")
        print("         API plumbing + auth verified; load a live case for data assertions.")
        return 0 if ok else 1
    ok &= check("auth /v1/case returns 200", code == 200, f"got {code}: {body[:80]}")
    running = code == 200

    if running:
        for path, fields in SCHEMAS.items():
            code, body = call(path)
            if code != 200:
                check(f"GET {path}", False, f"HTTP {code}: {body[:60]}")
                ok = False; continue
            try:
                data = json.loads(body)
                obj = data[0] if isinstance(data, list) and data else data
                missing = [f for f in fields if isinstance(obj, dict) and f not in obj]
                ok &= check(f"GET {path}", not missing,
                            f"missing {missing}" if missing else f"{type(data).__name__} ok")
            except Exception as e:
                ok &= check(f"GET {path} JSON", False, str(e))

    print(f"\n== {'ALL PASS' if ok else 'FAILURES'} ==")
    return 0 if ok else 1

if __name__ == "__main__":
    sys.exit(main())
