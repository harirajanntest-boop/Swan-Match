# What We Need to Publish Swan Match (App Store + Play Store)

This is the checklist of everything required to submit the app to Apple and Google.
Items marked ✅ are already done; ⬜ are still needed (mostly accounts, assets, and decisions).

---

## A. Developer accounts (needed before anything)
- ⬜ **Apple Developer Program** — $99/year. Use an **Organization** account (needs a D-U-N-S number for the company) so the company owns the app, not a personal Apple ID.
- ⬜ **Google Play Developer account** — $25 one-time.
- ⬜ A **Mac with Xcode** (or a build service) to build and upload the iOS app.

## B. Payment method decision (important — can cause rejection)
- ⬜ **Decide how premium is charged on mobile.** Apple and Google normally require their **own in-app purchase** for digital subscriptions (they take 15–30%). The app currently uses Stripe, which is fine for the website but is a common rejection reason on iPhone. We need to decide: add Apple In-App Purchase / Google Play Billing, or use the limited external-payment options. *(This is the single biggest approval risk.)*

## C. Store listing assets (we prepare; client approves)
- ⬜ **App icon** — 1024×1024 (Apple), 512×512 (Google)
- ⬜ **Screenshots** — for several phone sizes (and tablet/iPad if supported)
- ⬜ **Feature graphic** (Google) — 1024×500
- ⬜ **App name, subtitle, short & full description, keywords**
- ⬜ **Category** — Lifestyle / Social / Dating
- ⬜ Optional: preview video

## D. Legal & privacy (mostly done ✅)
- ✅ **Privacy Policy, Terms, Community Guidelines, Subscription Terms** — live on swan-match.com
- ✅ **In-app account deletion** + **Data Deletion page** (both stores require this)
- ✅ **Support page / email** (support@swan-match.com)
- ⬜ **Apple "App Privacy" labels** — declare what data is collected (we fill this in App Store Connect)
- ⬜ **Google "Data Safety" form** — same idea, in Play Console
- ⬜ **Content rating questionnaire** (Google IARC) and **age rating 17+/18+** (Apple) — dating apps are adult-rated
- ⬜ **Google "Dating app" declaration** (Google requires this for dating apps)

## E. Review access (very important for a login app)
- ⬜ **A working demo/test account** (email + password) for the reviewers, since the app requires sign-in. Without this, reviewers reject the app because they can't log in.
- ⬜ Reviewer notes explaining how to test (login, see matches, etc.)

## F. Technical / build
- ⬜ **Signed release builds** — iOS `.ipa` (certificates + provisioning) and Android `.aab` (signing key — keep it safe and backed up)
- ⬜ **Bundle ID / package name** finalized (already `swan-match`-based)
- ✅ **Production backend** (Firebase) live and stable; load-tested
- ⬜ Push notification certificates/keys configured for production (APNs for iOS)

## G. Compliance features the stores check (mostly done ✅)
- ✅ Report & block users
- ✅ Content moderation + appeals
- ✅ Account deletion in-app
- ✅ Age gate (18+)
- ⬜ Confirm the user-generated-content safeguards are described in the listing

---

## Summary — what we need from the client
1. Open the **Apple ($99/yr) and Google ($25) developer accounts** (company-owned).
2. **Decide the mobile payment method** (Apple/Google billing vs Stripe) — needed to avoid rejection.
3. Approve the **store listing text + screenshots** once we prepare them.
4. Provide company details for the **D-U-N-S / organization** account.

Once those are in place, we handle the builds, store setup, privacy forms, and submission.
Note: Apple often rejects dating apps once or twice on the first try — that's normal, and we resubmit.
