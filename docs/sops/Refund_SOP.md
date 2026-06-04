# SOP: Refunds

> **Step 23 — Internal documentation.** Standard operating procedure for handling refund requests.
> Audience: Support Admin and Finance Admin.

## When a refund is appropriate
- Accidental/duplicate charge, or billed after a confirmed cancellation.
- Charge during a period the user could not access premium due to a confirmed bug.
- Required by law or by Stripe chargeback resolution.
- Goodwill (manager discretion) — log the reason.

## When to decline
- "Changed my mind" after using premium for a full billing cycle (per Subscription Terms: no refunds once a cycle starts, unless required by law).
- Account suspended/banned for guidelines or fraud violations (balances are forfeited per Terms).

## How to issue a refund (admin)
1. Open the **admin web** → find the user (Users) or the support ticket (Support Queries).
2. Verify the charge in **Stripe Dashboard → Payments** (match customer email + amount + date).
3. Issue the refund via the admin: the **Support Queries** page calls the `processRefund` Cloud Function
   (`SupportQueries.jsx`). Enter the reason; the action is recorded to the **admin audit log**
   (`admin_audit_logs`, action `process_refund`).
4. If the admin path is unavailable, refund directly in **Stripe Dashboard → Payment → Refund**, then
   note it in the user's record.
5. Confirm the user's premium status updates correctly (the `customer.subscription.*` / `invoice.*`
   webhook will sync Firestore — see the Stripe webhook in `functions/index.js`).
6. Reply to the user from **billing@swan-match.com** confirming the refund and timeline (5–10 business days).

## Targets
- First response: within 48 hours (matches the Help page commitment).
- Refund decision + action: within 3 business days.

## Escalation
- Disputed/chargeback or amount over [set a threshold, e.g. $200]: escalate to Finance Admin / founder.
- See `docs/sops/Escalation_Tree.md`.

## Record-keeping
- Every refund is logged automatically in `admin_audit_logs`. Do not issue out-of-band refunds without a logged reason.
- Track refund % monthly (it appears in the admin Analytics dashboard) — a rising rate signals a product or billing problem.
