# Escalation Tree

> **Step 23 — Internal documentation.** Who handles what, and when to escalate. Fill in the names.
> Admin roles already exist in the web panel: **Super Admin, Support Admin, Finance Admin, Verification Admin**
> (`Swan-Match-Web/.../adminPermissions.js`).

## Roles & owners
| Role | Person | Handles |
|---|---|---|
| Super Admin | __________ | Everything; final approver for bans, escalated reports, role changes |
| Support Admin | __________ | Tickets, general user issues, warnings |
| Finance Admin | __________ | Refunds, chargebacks, billing disputes |
| Verification Admin | __________ | ID/profile verification approvals |
| Developer / On-call | __________ | Outages, bugs, deploys |
| Founder | __________ | Business decisions, legal, press |

## Escalation paths

### User reports / moderation
Support Admin reviews → routine action (warn/suspend/dismiss) handled directly.
→ Escalate to **Super Admin** when: harassment with threats, repeat offender, fake-profile ring,
or anything legal/PR-sensitive.
→ Escalate to **Founder + authorities** when: child safety, credible threat of harm, or law-enforcement request.
(Reports flow + escalation is built into `Reports.jsx`.)

### Billing / refunds
Support Admin → Finance Admin for any refund.
→ Escalate to **Founder** for chargebacks, amounts over [threshold], or suspected fraud rings.
(See `docs/sops/Refund_SOP.md`.)

### Technical incidents
On-call Developer assesses severity (`Incident_Response_Runbook.md`).
→ SEV-1/SEV-2: notify **Founder** immediately and pull in additional help.
→ Data breach / compromise: Founder + **legal counsel**.

### Appeals
User submits appeal (`submitAppeal`) → appears in admin Appeals queue → **Super Admin** decides
(`adminResolveAppeal`); approved appeals auto-unsuspend the user.

## Response-time standards
| Severity | Acknowledge | Resolve target |
|---|---|---|
| Child safety / threat of harm | Immediately | Suspend now; report same day |
| SEV-1 outage / payments down | < 1 hour | Same day |
| Reports (standard) | < 24 hours | < 48 hours |
| Support tickets | < 48 hours | Per issue |
| Refunds | < 48 hours | < 3 business days |
