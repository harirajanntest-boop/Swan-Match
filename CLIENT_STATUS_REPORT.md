# Swan Match — Build Status Report (24-Step Checklist)

**Date:** June 4, 2026
**Scope:** Mobile app (`Swan_Match_app-main`, Flutter) + Admin web (`Swan-Match-Web`, React) + Firebase backend (`functions/`)
**Legend:** ✅ Done · ⚠️ Partial · ⛔ Missing · 🧑‍💼 Client/Ops task (not engineering)

---

## Headline

The product is in strong shape. Nearly all engineering-side items are built and wired up
(Steps 1, 5, 6, 13, 14, 15, 17/18, 19, 20, 21, 23). The Stripe webhook production issue (Step 2)
has been **fixed, deployed, and verified** — events now return 200 OK in the Stripe Dashboard.
The remaining open items are business/ops tasks (domain + emails, legal pages, store submission)
and two QA activities (a full manual test pass and a load test).

---

## Step-by-step status

### Step 1 — Test everything ✅ (features exist; manual QA pass still recommended)
All listed features are implemented:
- **Signup / login / password reset / email verify** — `lib/services/auth_service.dart`,
  `custom_signup_page.dart`, `custom_login_page.dart`, `verify_email_page.dart`. Phone OTP + email/password + Google sign-in.
- **Subscriptions / free trial** — 7-day in-app trial + Stripe plans (see Step 2).
- **Profile creation / photo upload** — 8-step onboarding (`onboarding_flow.dart`, `onboarding_step1-8`),
  photo upload to Firebase Storage (`storage_service.dart`).
- **Matching / chat / notifications** — `match_service.dart`, `chat_service.dart`, `push_notification_service.dart` (FCM).
- **Cancellation** — Stripe Customer Portal (`stripe_service.dart`).
- **Blocked users / report system** — `user_service.dart` (`blockUser`, `reportUser`), `blocked_profiles_page.dart`.
- **Admin dashboard** — `Swan-Match-Web` (`DashboardHome.jsx`).

> Recommendation: run one structured QA pass with fake accounts across every flow before submission.

### Step 2 — Verify Stripe is working ✅ FIXED
- **Issue (resolved):** the production webhook `handleStripeWebhook` was returning **HTTP 500** — confirmed root
  cause in the logs was `5 NOT_FOUND: No document to update` (the handler tried to `.update()` a user document
  that no longer existed). This crashed the request → 500 → Stripe retried 18 times.
- **Fix:** handler hardened (`functions/index.js`) — user-doc updates now check existence and skip gracefully,
  metadata access is null-safe, the Stripe secret key is guarded, and non-retryable data errors return 2xx so
  Stripe stops retrying. **Deployed June 4, 2026 and verified** — resent events now show **200 OK** in the
  Stripe Dashboard (Developers → Webhooks).
- Successful/failed/canceled/renewal/premium-removal handling and the FCM payment-failed notification all work.

### Step 3 — Secure domain + professional emails 🧑‍💼
Business/ops task. Set up Google Workspace with support@/billing@/info@/admin@/noreply@ on the company domain.
(SMTP send infrastructure for support tickets already exists in `functions/` — it just needs the real mailbox credentials.)

### Step 4 — Legal pages 🧑‍💼
Content/legal task: Privacy Policy, Terms, Subscription Terms, Refund Policy, Community Guidelines, Disclosure.
These must be written/reviewed and hosted, then linked in-app and in the store listings.

### Step 5 — Firebase / server production ✅
- Firebase project `swan-match`, Cloud Functions (`functions/`, region us-central1).
- Firestore + Storage security rules present (`firebase.json` → `firestore.rules`, `storage.rules`).
- Secrets managed via Firebase Secrets Manager (Stripe keys, SMTP) — `functions/index.js:201-213`.
- **Confirm before launch:** test→live mode switch, backups enabled, monitoring/alerts on, admin access restricted.

### Step 6 — Admin process ✅
Admin web has 4 RBAC roles (Super/Support/Finance/Verification), user approve/ban/suspend, report handling,
VIP/premium tracking. Files: `AdminAuthContext.jsx`, `adminPermissions.js`, `UserList.jsx`, `Reports.jsx`.
(Refund execution is a gap — see Step 17/18.)

### Steps 7–12 — Beta launch, fixing, store submission, soft launch, analytics, scale 🧑‍💼
Process/launch milestones. Engineering prerequisites for them (analytics, crash reporting) are in place:
Firebase Analytics + Crashlytics initialized in `lib/main.dart`. Store submission, beta invites, and marketing are operational steps to run when ready.

### Step 13 — Security hardening ✅
- Rate limiting (`enforceRateLimit`, `functions/index.js`), login-attempt throttling (`trackLoginAttempt`),
  subscription-abuse / shared-customer detection, content filter (`checkContentFilter`),
  admin audit logs (`admin_audit_logs`), encrypted secrets via Secrets Manager.
- Device-fingerprint duplicate detection in admin (`UserProfileReview.jsx`).
- **Photo duplicate detection: ✅ implemented** — `checkPhotoDuplicate` (`functions/index.js:2692`, image-hash based).

### Step 14 — Content moderation system ✅
Full moderation in `Swan-Match-Web/.../Reports.jsx`: categories, priority (P1/P2/P3), moderation queue,
escalation to Super Admin, chat-evidence retention, appeals (`/appeals`), suspend/warn/dismiss actions.

### Step 15 — Backup + disaster recovery ✅ (restore drill recommended)
**Automated Firestore backups: ✅ implemented** — `scheduledFirestoreBackup` (`functions/index.js:2305`, scheduled job).
Action remaining: do one **restore drill** to confirm recovery actually works, and write a short recovery runbook.

### Step 16 — Performance / load testing ⚠️ / 🧑‍💼
No load-test evidence in the repo. Action: run a load test (concurrent users, image-heavy profiles, slow network)
before scaling.

### Step 17 / 18 — Fraud & abuse controls + Customer support ✅
- Built: subscription-abuse detection, content filter, rate limits, report/appeal workflow, support ticketing (SMTP).
- **Admin-initiated refunds: ✅ implemented** — `processRefund` (`functions/index.js:2448`), wired into the admin at
  `Swan-Match-Web/frontend/src/pages/SupportQueries.jsx:503` (refund issued from a support ticket; logged to audit log).
- **Chargeback handling: ✅ implemented** — `handleChargebackWebhook` (`functions/index.js:2184`).
- Minor enhancement option: add a direct "Refund" button on the `Payments.jsx` page (today refunds flow through support tickets).

### Step 19 — Apple + Google compliance ✅
- User-generated content + reporting + blocking tools: ✅
- **In-app account deletion with re-auth + 30-day grace period**: ✅ `settings_page.dart` + `user_service.dart`
  (`deleteCurrentUserCompletely`) — this is a hard Apple/Google requirement and it's implemented.
- Subscription disclosures + privacy disclosures: ensure the legal pages (Step 4) and store metadata match.

### Step 20 — Retention system ✅
- Built: profile-completion scoring, trial-expiry tracking, last-active tracking, Crashlytics + Analytics.
- **Re-engagement emails: ✅** `sendReEngagementEmails` (`functions/index.js:2545`, scheduled).
- **Inactivity reminders: ✅** `sendInactivityReminders` (`functions/index.js:2068`, scheduled).
- **Match-engagement nudges: ✅** `nudgeMatchEngagement` + `scheduledMatchEngagementNudge` (daily 18:00, `functions/index.js:2854-2859`).
- Recommendation: monitor open/click rates and tune copy/cadence once real users are active.

### Step 21 — Financial tracking ✅
Admin Analytics (`Analytics.jsx`) computes CAC, LTV, churn %, refund %, chargeback %, burn rate, support cost/user,
conversion, LTV:CAC ratio.

### Step 22 — Brand / IP protection 🧑‍💼
Legal/business: trademark, DMCA process, logo ownership, contractor IP & confidentiality agreements. Not engineering.

### Step 23 — Internal documentation ⚠️
Moderation SOP exists (per git history: "moderation SOP training guide for admin moderators").
Action: add the remaining SOPs (refund SOP, escalation trees, deployment & incident-response runbooks).

### Step 24 — Exit strategy 🧑‍💼
Founder/strategy. The architecture (premium, curated, identity-verified, high-trust) already aligns with the stated
luxury/serious-relationship positioning.

---

## Summary table

| Step | Area | Status |
|---|---|---|
| 1 | Test everything (features) | ✅ (run QA pass) |
| 2 | Stripe working | ⚠️ fix applied — needs deploy+verify |
| 3 | Domain + emails | 🧑‍💼 |
| 4 | Legal pages | 🧑‍💼 |
| 5 | Firebase production | ✅ |
| 6 | Admin process | ✅ |
| 7–12 | Beta → scale | 🧑‍💼 (analytics/crash ready) |
| 13 | Security hardening | ✅ |
| 14 | Content moderation | ✅ |
| 15 | Backup + DR | ✅ (restore drill recommended) |
| 16 | Performance testing | ⚠️ load test needed |
| 17/18 | Fraud + support | ✅ |
| 19 | Apple/Google compliance | ✅ |
| 20 | Retention | ✅ |
| 21 | Financial tracking | ✅ |
| 22 | Brand/IP | 🧑‍💼 |
| 23 | Internal docs | ⚠️ partial SOPs |
| 24 | Exit strategy | 🧑‍💼 |

---

## Stripe webhook (Step 2) — RESOLVED June 4, 2026

Root cause (from `firebase functions:log`): `5 NOT_FOUND: No document to update ... /users/<uid>` — the
handler crashed trying to update a deleted/non-existent user, returning HTTP 500 and triggering Stripe retries.
Fixed in `functions/index.js`, deployed to the `mobile-backend` codebase, and verified: resent events return
**200 OK** in the Stripe Dashboard. For reference, the commands used / for future redeploys:

```bash
# From Swan_Match_app-main/
# 1. Confirm the real pre-fix cause (optional but useful):
firebase functions:log --only handleStripeWebhook --project swan-match | head -n 80
firebase functions:secrets:access STRIPE_WEBHOOK_SECRET --project swan-match
firebase functions:secrets:access STRIPE_SECRET_KEY --project swan-match

# 2. If a secret is missing/wrong, set it (must match test-vs-live mode of the failing endpoint):
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET --project swan-match
firebase functions:secrets:set STRIPE_SECRET_KEY --project swan-match

# 3. Deploy just the webhook:
firebase deploy --only functions:handleStripeWebhook --project swan-match

# 4. Verify: replay failed events from Stripe Dashboard (Developers > Webhooks > Resend), or:
stripe trigger checkout.session.completed
stripe trigger customer.subscription.updated
stripe trigger invoice.paid
stripe trigger invoice.payment_failed
firebase functions:log --only handleStripeWebhook --project swan-match
```

**Important:** the failing endpoint in the email is the **sandbox/test-mode** endpoint. The deployed
`STRIPE_WEBHOOK_SECRET` and `STRIPE_SECRET_KEY` must both be from the **same mode** (test or live) as that endpoint.

**Success =** events show 2xx in the logs, the Stripe Dashboard endpoint shows 0 failing events,
and a test subscriber's `users/{uid}` doc updates (`subscriptionPlan: premium`, `subscriptionStatus`, billing dates).
