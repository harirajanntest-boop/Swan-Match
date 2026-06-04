# Exit Strategy & Positioning

> **Step 24 — Exit strategy thinking.** Not because you're selling soon, but because the path you
> pick changes what you build now. This is a living strategy doc for the founder.

## Positioning (the foundation everything else rests on)
Swan Match is intentionally **premium, curated, identity-verified, high-trust, serious-relationship
focused, AI-assisted, luxury-positioned**. This is a deliberate niche — *not* a mass-market Tinder
clone. Every product and operations decision should reinforce trust and exclusivity, because that's
the moat and the thing an acquirer or premium user actually pays for.

## The realistic exit options
| Path | What it means | Build-now implication |
|---|---|---|
| **Acquisition** (most common for dating apps) | Sold to a larger dating company (e.g., a Match Group / Bumble-type) or a regional player | Clean cap table, owned IP, strong retention + revenue metrics, no legal/IP loose ends |
| **Lifestyle business** | Stays small, profitable, founder-run | Keep burn low, automate ops/moderation, focus on margin |
| **Scale / venture** | Raise capital, grow aggressively | Need defensible metrics, unit economics that improve with scale, fundraising story |
| **Premium niche platform** | Stay boutique, high-price, curated | Double down on curation, concierge, exclusivity; smaller but loyal base |

The current architecture (verification, premium tiers, curation, AI compatibility) keeps **acquisition**
and **premium-niche** open — which are the most realistic for a luxury matchmaking product.

## What acquirers actually look at (build toward these now)
1. **Retention** — D1/D7/D30 retention and cohort curves. A leaky bucket kills value. (Your retention
   loops exist: re-engagement emails, inactivity reminders, match nudges — instrument and tune them.)
2. **Revenue quality** — MRR, subscription LTV, churn %, LTV:CAC ratio (≥3:1). Your admin Analytics
   already computes these — keep them honest and trending the right way.
3. **Clean IP & cap table** — every contractor signed the IP assignment; company owns all code, logo,
   accounts. (See `docs/legal/` and `docs/brand/`.) This is the #1 thing that scares off acquirers if missing.
4. **Trust & safety maturity** — moderation, reporting, appeals, audit logs, compliance. You have these;
   keep the SOPs current (`docs/sops/`).
5. **Low key-person risk** — documented ops, no single contractor holding the keys. (Escalation tree, runbooks.)
6. **Compliance** — Apple/Google compliance, privacy, account deletion, legal pages finalized.

## Metrics dashboard to watch (from day one)
- Activation: % completing onboarding + verification.
- Engagement: DAU/MAU, matches per active user, messages per match.
- Monetization: trial→paid conversion, MRR, ARPU, churn %, refund %, chargeback %.
- Unit economics: CAC, LTV, LTV:CAC, payback period, burn rate.
(Most of these are already in the admin Analytics page — make reviewing them a weekly ritual.)

## Near-term moves that protect every exit path
- [ ] Finalize IP ownership (contractor agreements signed, accounts on company emails).
- [ ] Register the trademark (`docs/brand/Trademark_Protection_Checklist.md`).
- [ ] Keep clean monthly financials (CAC, LTV, churn, burn) — even a simple spreadsheet.
- [ ] Resolve the Apple IAP question before scaling paid acquisition (App Store risk).
- [ ] Maintain trust & safety quality as you grow — it's the brand's core asset and a due-diligence checkpoint.

## Note
Don't optimize prematurely for exit. The best exit outcome comes from building a genuinely retentive,
trusted, profitable product. These notes just make sure you don't accidentally destroy optionality
(e.g., messy IP, personal-account ownership, untracked finances) while you build.
