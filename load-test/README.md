# Tier 2 Load Test — Firestore chat + profile reads (Emulator)

Tests the database layer (where real apps bottleneck) — the client's "1,000 messages" and
"image-heavy / concurrent profile reads" targets. Runs against the **Firebase Emulator** only,
so it is **free, isolated, and cannot touch production data**.

## Prerequisites
- Firebase CLI installed (`firebase --version`).
- Dependencies already present in `functions/` (uses `firebase-admin`).

## Run it

**Terminal A — start the emulator** (from the app repo root):
```bash
cd /Users/apple/Downloads/Swan_Match_app-main
firebase emulators:start --only firestore,functions,auth
```
(Including `functions` also exercises the `onMessageCreated` trigger under load. Drop it to
`--only firestore` if you just want raw DB throughput without the trigger.)

**Terminal B — run the load test** (point it at the emulator):
```bash
cd /Users/apple/Downloads/Swan_Match_app-main/functions
FIRESTORE_EMULATOR_HOST=localhost:8080 GCLOUD_PROJECT=swan-match \
  node ../load-test/firestore_chat_load.js
```

Heavier run:
```bash
MESSAGES=5000 CONCURRENCY=100 PROFILE_READS=2000 \
FIRESTORE_EMULATOR_HOST=localhost:8080 GCLOUD_PROJECT=swan-match \
  node ../load-test/firestore_chat_load.js
```

> The script **refuses to run** unless `FIRESTORE_EMULATOR_HOST` is set — a safety guard so it can
> never hit production.

## Read the results
The script prints throughput + latency for chat writes and profile reads:

| Metric | Pass |
|---|---|
| Chat write throughput | > 100 messages/sec |
| Profile read p95 | < 200 ms |
| Errors | none |

If write throughput is low or you see contention, the usual causes are: too many writes to one
"hot" document, or a missing Firestore composite index (the emulator logs index hints).

## Note on production reality
The emulator runs on your laptop, so absolute numbers differ from production Cloud Firestore — but it
reliably surfaces **logic problems**: hot documents, missing indexes, unbounded queries, and slow
trigger code. A clean emulator run + the Tier 1 API test (passed: 0 errors, p95 310ms at 100 VUs)
together are solid evidence for checking off Step 16.
