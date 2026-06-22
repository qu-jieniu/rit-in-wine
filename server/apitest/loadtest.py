#!/usr/bin/env python3
"""
RIT API load test — hammer the API to exercise the per-trader token-bucket rate
limiter and concurrency (the suspected crash/race surface). Reports throughput,
rate-limited (429) vs ok (200) vs SERVER ERRORS (5xx) and latency. 5xx / connection
drops are the red flags for the crash/race-condition behavior you recalled.

Point it at a live RIT API (client :9999 -> flserver, or your server :10002).
Multiple traders exercise the per-trader locking; raise --rate above the case's
configured commands/second to trigger throttling on purpose.

Usage:
  RIT_API=http://localhost:9999 ./loadtest.py --workers 20 --seconds 30 \
     --creds trader1:pw1 --creds trader2:pw2 --path /v1/securities
"""
import argparse, base64, os, sys, threading, time, urllib.request, urllib.error

def worker(base, auth, path, stop, stats, lock):
    req_url = base + path
    while not stop.is_set():
        t0 = time.monotonic()
        req = urllib.request.Request(req_url, headers={"Authorization": auth})
        try:
            with urllib.request.urlopen(req, timeout=10) as r:
                code = r.status; r.read()
        except urllib.error.HTTPError as e:
            code = e.code;
            try: e.read()
            except Exception: pass
        except Exception:
            code = "ERR"          # connection reset/refused — possible crash
        dt = time.monotonic() - t0
        with lock:
            stats["n"] += 1
            stats["lat"] += dt
            stats["max"] = max(stats["max"], dt)
            k = (200 if code == 200 else 429 if code == 429 else
                 "5xx" if isinstance(code, int) and 500 <= code < 600 else
                 "ERR" if code == "ERR" else code)
            stats["codes"][k] = stats["codes"].get(k, 0) + 1

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--workers", type=int, default=10)
    ap.add_argument("--seconds", type=int, default=20)
    ap.add_argument("--path", default="/v1/case")
    ap.add_argument("--creds", action="append", default=[], help="trader:password (repeatable)")
    args = ap.parse_args()
    base = os.environ.get("RIT_API", "http://localhost:9999").rstrip("/")
    creds = args.creds or ([f"{os.environ.get('RIT_USER','')}:{os.environ.get('RIT_PASS','')}"]
                           if os.environ.get("RIT_USER") else [])
    if not creds:
        print("need --creds trader:pw (or RIT_USER/RIT_PASS)"); return 2
    auths = [base64.b64encode(c.encode()).decode() for c in creds]

    stop = threading.Event(); lock = threading.Lock()
    stats = {"n": 0, "lat": 0.0, "max": 0.0, "codes": {}}
    threads = [threading.Thread(target=worker,
               args=(base, auths[i % len(auths)], args.path, stop, stats, lock), daemon=True)
               for i in range(args.workers)]
    print(f"== load test {base}{args.path}: {args.workers} workers x {args.seconds}s, "
          f"{len(creds)} trader(s) ==")
    t0 = time.monotonic()
    for t in threads: t.start()
    time.sleep(args.seconds)
    stop.set()
    for t in threads: t.join(timeout=5)
    elapsed = time.monotonic() - t0

    n = stats["n"]
    print(f"  requests:   {n}  ({n/elapsed:.0f}/s)")
    print(f"  latency:    avg {1000*stats['lat']/max(n,1):.1f} ms, max {1000*stats['max']:.0f} ms")
    for k, v in sorted(stats["codes"].items(), key=lambda x: str(x[0])):
        print(f"  {k}: {v}")
    bad = stats["codes"].get("5xx", 0) + stats["codes"].get("ERR", 0)
    print(f"\n  >>> {'CLEAN — no server errors/drops' if bad == 0 else f'WARNING: {bad} server errors / connection drops (crash/race indicator)'}")
    return 0 if bad == 0 else 1

if __name__ == "__main__":
    sys.exit(main())
