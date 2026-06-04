# Brand Asset & Ownership Register

> **Step 22 — Brand / IP protection.** A single source of truth for *what the company owns and who
> controls it*. Fill in the owners. The goal: every critical account is owned by a **company email**
> (not a personal Gmail) and has a documented backup owner, so the business never depends on one
> person or a contractor for access. Investors/acquirers will ask for exactly this list.

> ⚠️ **Do NOT store passwords or secret keys in this file.** Put credentials in a password manager
> (1Password/Bitwarden) and reference them here by name only.

## Critical accounts

| Asset | Account / location | Should be owned by | Current owner | Backup owner | Status |
|---|---|---|---|---|---|
| Domain registrar | swan-match.com | company email | | | ☐ |
| Google Workspace (email) | swan-match.com mailboxes | company admin | | | ☐ |
| Firebase / Google Cloud project | `swan-match` | company Google account | | | ☐ |
| Apple Developer account | App Store Connect | **company (Organization, not Individual)** | | | ☐ |
| Google Play Console | Play Console | company account | | | ☐ |
| Stripe account | acct (Swan Match) | company | | | ☐ |
| Source code | GitHub/GitLab org | company org (not personal repo) | | | ☐ |
| Logo / brand master files | company drive | company | | | ☐ |
| Social handles | IG/TikTok/X/FB/YouTube | company | | | ☐ |
| Analytics | Firebase Analytics / GA | company | | | ☐ |
| Support/SMTP mailboxes | support@, billing@, admin@, noreply@, dmca@ | company | | | ☐ |

## Email addresses in use (verify each mailbox exists & is monitored)
- [ ] support@swan-match.com  (referenced in Help, Data Deletion pages)
- [ ] billing@swan-match.com
- [ ] admin@swan-match.com
- [ ] noreply@swan-match.com  (transactional email sender)
- [ ] privacy@swan-match.com  (referenced in Privacy Policy)
- [ ] dmca@swan-match.com  (referenced in Terms — DMCA agent)

## Ownership hygiene rules
- [ ] Every account above is owned by a **company email**, never a personal account.
- [ ] Each account has **2FA** enabled and recovery codes stored in the password manager.
- [ ] Apple Developer account is an **Organization** account (needs a D-U-N-S number) — individual accounts can't transfer ownership cleanly and complicate acquisition.
- [ ] At least **two people** can recover each critical account (no single point of failure).
- [ ] When a contractor leaves, their access is removed (see offboarding §8 of the Contractor agreement).

## Cross-references
- `docs/legal/Contractor_IP_Assignment_and_NDA.md`
- `docs/brand/Trademark_Protection_Checklist.md`
- `docs/sops/Incident_Response_Runbook.md` (account-compromise response)
