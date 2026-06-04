# Runbook: Incident Response

> **Step 23 — Internal documentation.** What to do when something breaks or is compromised.
> Audience: founder, developer, admins. Keep this short enough to follow under pressure.

## Severity levels
- **SEV-1 (critical):** app down, payments broken, data breach, child-safety report. Respond now.
- **SEV-2 (high):** a core feature broken for many users (chat, login, matching). Respond same day.
- **SEV-3 (moderate):** minor/cosmetic, single-user issue. Normal queue.

## General response loop
1. **Acknowledge** — note start time, who's on it.
2. **Assess** — severity, scope (how many users), is data/payment/safety involved?
3. **Mitigate** — stop the bleeding (disable a feature, roll back, revoke a key).
4. **Fix** — root-cause and deploy the fix (see `Deployment_Runbook.md`).
5. **Verify** — confirm resolved via logs / smoke test.
6. **Postmortem** — for SEV-1/2, write a short what-happened / why / prevention note.

## Playbooks

### Payments / Stripe failing
- Check `firebase functions:log --only handleStripeWebhook --project swan-match`.
- Verify secrets (`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`) are set and test/live mode matches the endpoint.
- Stripe Dashboard → Webhooks → check delivery status; use **Resend** to replay failed events.
- Confirm the webhook returns 2xx after a fix and Firestore user docs update.

### App backend errors / function crashes
- `firebase functions:log --project swan-match` — find the throwing function + stack trace.
- Roll back to the last-known-good commit if a recent deploy caused it.

### Account / credential compromise
- Rotate the affected secret/key immediately (Firebase Secrets, Stripe, registrar, Google Workspace).
- Force-revoke contractor access (GitHub, Firebase, Stripe, consoles).
- Enable/verify 2FA on all critical accounts (see `docs/brand/Brand_Asset_Ownership_Register.md`).

### Data breach / privacy incident
- Contain (revoke access, take affected systems offline).
- Determine what data was exposed and which users.
- Notify affected users and regulators as required by law (GDPR: within 72 hours where applicable).
- Document everything; consult legal counsel.

### Child-safety / underage report (highest priority)
- Immediately suspend the account(s) involved via the admin (`adminSuspendUser`).
- Preserve evidence (do not delete) and report to the relevant authorities (e.g., NCMEC in the US).
- Remove violating content within 24 hours (per Community Guidelines commitment).

### Data loss / need to restore
- Automated backups run via `scheduledFirestoreBackup` (`functions/index.js`).
- Restore from the latest Firestore export; verify integrity. **Do a restore drill before you need it** (Step 15).

## Contacts (fill in)
- On-call developer: ____________________
- Founder / decision-maker: ____________________
- Legal counsel: ____________________
- Stripe support / Firebase support: via respective dashboards.

See also `docs/sops/Escalation_Tree.md`.
