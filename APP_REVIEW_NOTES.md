# App Store Review Notes — Paste into App Store Connect

Use this text in **App Store Connect → App Review Information → Notes** when you resubmit.

Also fill in the **demo account** fields with a real expired-subscription account.

---

## Review Notes (copy below)

```
Thank you for the feedback. We addressed all issues in this build:

1) Guideline 5.1.1(iv) — Camera / Microphone
We now always show the native iOS permission dialog first. “Open Settings” appears only after the user has permanently denied access. Settings is never shown before the system permission request.

2) Guideline 2.1(a) — Sign in with Apple on iPad
We fixed Sign in with Apple for iPhone and iPad (compatibility mode). Please retry “Continue with Apple”. A backup email/password demo account is also provided below.

3) Guideline 2.1 — Subscription purchase flow
Please use the EXPIRED subscription demo account below to test the full IAP purchase flow (no active Premium).

4) Guideline 5.1.1(v) — Government ID
Government ID is now OPTIONAL during onboarding. Users can complete onboarding and use core features with only a selfie. ID can be uploaded later under Profile → Verify Profile.

—— DEMO ACCOUNTS ——

A) Expired subscription (REQUIRED for IAP testing)
Email: [PUT_EXPIRED_ACCOUNT_EMAIL]
Password: [PUT_PASSWORD]
This account has no active subscription.
Path: Profile / Settings → Upgrade / Subscription → choose a plan → complete StoreKit purchase.

B) Active / main demo (marriage features)
Email: [PUT_MAIN_DEMO_EMAIL]
Password: [PUT_PASSWORD]
Use this to review Marriage Dashboard, Today’s Recommendations, AI Match Explanation, and Relationship Journey.

—— REVIEW PATH ——
1. Sign in with account A or B
2. Home = Marriage Dashboard
3. Today’s Marriage Recommendations
4. AI Match Explanation on a profile
5. Relationship Journey (5 stages)
6. Optional: Sign in with Apple on an iPad or iPhone
```

---

## What you must create before upload

1. **Firebase Auth user** for expired subscription, e.g. `review.expired@swanmatch.com`
2. In **Firestore** for that user, set subscription so it is **not active**, for example:
   - `subscriptionStatus`: `expired` (or remove active plan fields)
   - `isPremium` / paid flags: `false`
   - No valid `billingPeriodEnd` in the future
3. Confirm IAP products are **Ready to Submit** in App Store Connect:
   - `swan_premium_monthly`
   - `swan_premium_6month`
   - `swan_premium_yearly`
4. Bump build number (e.g. **1.0 (11)**) and upload a new IPA
5. Paste the notes above and fill the demo credentials

---

## Code fixes included in this resubmission

| Issue | Fix |
|-------|-----|
| Camera/mic → Settings first | Native dialog first; Settings only if permanently denied |
| Apple Sign-In on iPad | Fresh auth (no stale link), availability check, clearer errors |
| Government ID required | ID optional in onboarding; Discover no longer gated on ID |
| Expired subscription demo | You add credentials in App Store Connect (this file) |
