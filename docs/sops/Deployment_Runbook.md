# Runbook: Deployment

> **Step 23 — Internal documentation.** How to safely deploy the three parts of Swan Match.
> Audience: developer / DevOps. Firebase project: `swan-match` (region `us-central1`).

## Components
1. **Mobile app** — Flutter (`Swan_Match_app-main`), shipped via App Store / Play Store.
2. **Cloud Functions backend** — `Swan_Match_app-main/functions` (codebase `mobile-backend`).
3. **Admin web** — React/Vite (`Swan-Match-Web/frontend`) + Express backend / functions.

## Pre-deploy checklist
- [ ] Changes committed to git on a branch; reviewed; merged to main.
- [ ] `firebase use swan-match` (or pass `--project swan-match`).
- [ ] No secrets committed. Secrets live in Firebase Secrets Manager (see below).
- [ ] Test/live Stripe mode is correct for the target environment.

## Deploy: Cloud Functions
```bash
cd Swan_Match_app-main
# Lint/syntax check first:
node --check functions/index.js
# Deploy ALL functions in the codebase:
firebase deploy --only functions --project swan-match
# Or a single function (note the codebase prefix is required):
firebase deploy --only functions:mobile-backend:handleStripeWebhook --project swan-match
```
- If prompted to **delete** functions "found in your project but not in local source"
  (e.g. `createTestUsers`, `deleteTestUsers`), choose **No** unless you intend to remove them.
- ⚠️ Node.js 20 runtime is deprecated (decommission 2026-10-30). Plan an upgrade to Node 22
  (`functions/package.json` already targets 22; update `firebase.json` runtime and re-test).

## Secrets (Firebase Secrets Manager)
```bash
firebase functions:secrets:set STRIPE_SECRET_KEY   --project swan-match
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET --project swan-match
firebase functions:secrets:set STRIPE_PRICE_MONTHLY  --project swan-match
firebase functions:secrets:set STRIPE_PRICE_SIXMONTH --project swan-match
firebase functions:secrets:set STRIPE_PRICE_YEARLY   --project swan-match
# Optional email: SMTP_USER, SMTP_PASS
firebase functions:secrets:access STRIPE_WEBHOOK_SECRET --project swan-match   # verify
```
After changing a secret, **redeploy** the functions that use it so they bind the new version.

## Deploy: Firestore / Storage rules
```bash
firebase deploy --only firestore:rules,storage --project swan-match
```

## Deploy: Admin web
```bash
cd Swan-Match-Web/frontend
npm ci
npm run build
# Deploy to your host (Firebase Hosting / Vercel / etc.) — confirm the live target.
# If Firebase Hosting:  firebase deploy --only hosting --project swan-match
```
- Confirm `VITE_API_BASE_URL` points to the production API (used by the Help/Support form `/support` endpoint).

## Deploy: Mobile app
- Bump version in `pubspec.yaml`.
- `flutter build appbundle` (Android) / `flutter build ipa` (iOS).
- Upload via Play Console / App Store Connect. Keep signing keys in the password manager.

## Post-deploy verification
- [ ] `firebase functions:log --project swan-match` — no new errors.
- [ ] Stripe Dashboard → Webhooks → endpoint shows 2xx.
- [ ] Smoke test: signup, login, a test-card purchase, premium unlocks, cancel.

## Rollback
- Functions: redeploy the previous git commit.
- Web: redeploy the previous build / revert the host to the prior deployment.
- Always have the last-known-good commit hash noted before deploying.
