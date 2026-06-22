# RIT API test suite

Real API tests for the RIT v1 REST API — stdlib Python, no deps. Same `/v1` schema
for both RIT APIs, so it runs against either:

- **Client API** (`:9999`) with the client connected to a **live case**
  (e.g. `flserver.rotman.utoronto.ca`) — legitimate with your trader credentials.
  This is the real-data path available without a server license.
- **Server/DMA API** (`:10002`) on your self-hosted server — once the license is renewed.

Auth is HTTP Basic, token = `base64("TraderID:Password")`. Data endpoints require a
**running simulation**; with no live case they return 401 *"Simulation must be running"*
(reported distinctly — the API works, there's just no case).

## Functional suite
```bash
RIT_API=http://localhost:9999 RIT_USER=trader1 RIT_PASS=pw ./rit_api_test.py
```
Checks unauth 401, authenticated access, and asserts response schemas for
`/v1/case`, `/v1/trader`, `/v1/securities`, `/v1/orders`, etc.

## Load test (the crash/race investigation)
The server rate-limits per trader via a token bucket (`commands/second`, ≤1000),
with a per-trader lock. This hammers it to surface throttling vs **server errors /
connection drops** (the crash/race indicators):
```bash
RIT_API=http://localhost:10002 ./loadtest.py --workers 20 --seconds 30 \
   --creds trader1:pw1 --creds trader2:pw2 --path /v1/securities
```
Reports throughput, latency, and a breakdown of `200 / 429 / 5xx / ERR`. **5xx or
ERR (connection drops) = the crash/race behavior** to investigate; `429` is healthy
throttling. Run with several traders + a rate above the case's configured limit.

## Endpoints covered
`case · trader · limits · news · securities[/book/tas/history] · assets[/history] ·
leases · orders · tenders · commands/cancel` (full `/v1` route table).
