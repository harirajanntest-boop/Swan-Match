# Swan Match — Issue Tracker

Working list of known issues. Check off as we fix them, one by one.

---

## A. Security

- [ ] **A1 🔴 CRITICAL — Service-account key committed to git.** `Swan-Match-Web/backend/firebase-service-account.json` is in git history (full admin access). Fix: rotate the key in Firebase, remove from git history, keep gitignored.
- [x] **A2 🟠 Android release signed with DEBUG keys.** ✅ Fixed — now signed with the release upload key (`key.properties` + `upload-keystore.jks`, both gitignored).
- [ ] **A3 🟡 Unused location permissions.** Android `ACCESS_FINE/COARSE_LOCATION` + iOS `NSLocation…`. App uses typed city/country, not GPS. Fix: remove them.
- [ ] **A4 🟡 App Check uses debug provider.** `main.dart`. Fix: Play Integrity (Android) + App Attest (iOS) for production.
- [ ] **A5 🟡 27 empty `catch {}` blocks** swallow errors silently.

## B. UI / UX

- [ ] **B1 Admin web uses browser `alert()` popups** (Reports, Appeals, Settings, Notifications, UserProfileReview). Replace with toasts.
- [ ] **B2 Empty `onTap: () {}`** — dead button at `otp_verification_page.dart:563`.
- [ ] **B3 Silent failures** — failed login / subscribe / save shows the user nothing (see A5).
- [ ] **B4 `past_due` = instant premium loss** (`user_service.dart isPaidPremium`). Should keep access during the retry grace window.

## C. Features Not Working / Incomplete

- [ ] **C1 🔴 Apple Sign-In is a stub** ("coming soon") in `custom_login_page.dart` + `custom_signup_page.dart`. Apple Guideline 4.8 requires Sign-in-with-Apple if Google login exists → App Store rejection. Fix: implement it (or remove the button + Apple mentions).
- [ ] **C2 🔴 In-app purchase not implemented** — Stripe rejected by both stores. *(In progress — Android first.)*
- [ ] **C3 🟡 iOS push notifications** don't work — no APNs key uploaded + simulator can't receive. Needs real device + APNs key.
- [ ] **C4 🟡 No admin refund capability** — relies on "contact support".
- [ ] **C5 🟡 Stale duplicate `ios/GoogleService-Info.plist`** still tracked in git (deletion not committed).

---

## D. In-App Purchase — Android (current focus)

Client gave **Google Play Console access** and confirmed **in-app purchase for both stores**.

- [x] **D1** Create a **release keystore** + wire up signing (fixes A2). ✅ `android/app/upload-keystore.jks`
- [x] **D2** Build a signed **release AAB**. ✅ `build/app/outputs/bundle/release/app-release.aab`
- [ ] **D3** **Play Console:** create the app (`com.swanmatch.app`).
- [ ] **D4** **Play Console:** upload AAB to the **Internal testing** track.
- [ ] **D5** **Play Console:** create the **subscription products** (monthly / 6-month / yearly).
- [ ] **D6** **App:** add Google Play Billing (`in_app_purchase`) using those product IDs.
- [ ] **D7** **Backend:** validate purchases + handle Real-time Developer Notifications.
- [ ] **D8** **Internal testing:** add testers, test buy / renew / cancel / restore.
- [ ] **D9** Fix remaining errors.

---

## ✅ Already fixed this session
Admin email-wildcard auth hole · storage rules typo · `user_lookup` writes · font flicker · Discover tab-reset · reauth "invalid password" · email-verify double-tap · subscription-cancel messaging · swipe dead-end / reset · admin "free" badge · iOS false "Firebase setup required" · bundle-ID migration to `com.swanmatch.app`.
