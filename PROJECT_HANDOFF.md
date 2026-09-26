# Swan Match — Project Handoff & Session Summary

> Portable context for continuing work (e.g. in Antigravity/another agent). Covers the
> project, architecture, everything done in this session, current state, and what's pending.

---

## 1. Project Overview

- **Swan Match** — a Flutter dating / matrimony app (premium, serious matchmaking).
- **Package / bundle ID:** `com.swanmatch.app`
- **Components:**
  - **Mobile app** — Flutter (this repo): `/Users/apple/Downloads/Swan_Match_app-main`
  - **Backend** — Firebase project **`swan-match`** (Blaze plan): Firestore, Auth, Storage, Cloud Functions v2 (codebase `mobile-backend`), FCM, Crashlytics, Analytics, App Check.
  - **Admin web** — React/Vite at `/Users/apple/Downloads/Swan-Match-Web` (frontend + functions).
- **Flutter SDK:** `/Users/apple/flutter/bin` (Flutter 3.41.7). Add to PATH before flutter cmds.
- **Apple:** Team `X926DU4NP3` (Aero Airworthiness Certification LLC). Upload Apple ID: `sasikumar.s9951@gmail.com`. App Store Connect app id `6780640132`.
- **Google Play:** Swan Match developer account (client-owned). Service account for API:
  `439342747193-compute@developer.gserviceaccount.com`.

### Versioning rules
- `pubspec.yaml` → `version: 1.0.0+6`.
- **iOS and Android build numbers are independent.** Override per platform with `--build-number`.
- Current: **iOS = build 6**, **Android = versionCode 10** (needs 11, see pending).
- iOS reads build number from `ios/Flutter/Generated.xcconfig` (`FLUTTER_BUILD_NUMBER`), which is
  regenerated from pubspec — so keep pubspec's `+N` correct or it reverts.

---

## 2. Current State (snapshot)

| Item | State |
|---|---|
| iOS **build 5** | Uploaded to TestFlight (delivered via Transporter) |
| iOS **build 6** | Built & verified arm64-clean → `build/ios/ipa/Swan Match.ipa`. **Needs upload.** Contains Apple-error on-screen diagnostic + chat tick fix. |
| Android **AAB v10** | Built (has IAP base-plan code). **Missing the chat tick fix → needs v11.** |
| Backend `verifyIapPurchase` | Updated (basePlanId tier) + **deployed** |
| Apple Sign-In | Config verified correct; **still fails on a real device** — awaiting build-6 exact-error screenshot |
| Chat read receipts | Implemented (single/double tick) — in build 6, needs Android v11 |

---

## 3. Work Done This Session

### 3.1 Native IAP migration (Stripe → in_app_purchase)
- **`lib/services/iap_service.dart`** — rewritten **platform-aware**:
  - iOS: 3 separate products (`swan_premium_monthly`, `swan_premium_6month`, `swan_premium_yearly`)
    all in ONE App Store **Subscription Group** ("Swan Match Pro") → mutually exclusive.
  - Android: ONE subscription **`swan_premium`** with 3 **base plans** (`monthly`/`sixmonth`/`yearly`);
    querying returns one `GooglePlayProductDetails` per base plan; buying it uses its offer token.
  - Plan keys (`monthlyId='monthly'`, `sixMonthId='sixmonth'`, `yearlyId='yearly'`) abstract the
    platform difference, so `subscription_page.dart` needed no change.
  - **Auto-restore on init** — silently restores owned subscriptions so premium is granted (and the
    badge updates) without the user tapping "Restore". Fixes "already subscribed but no premium".
- **`functions/index.js` → `verifyIapPurchase`** — Android productId is now always `swan_premium`,
  so the tier comes from **`basePlanId`** (read from Play `subscriptionsv2.get` →
  `lineItems[].offerDetails.basePlanId`). iOS still maps tier from its product id. **Deployed**
  (`firebase deploy --only functions:mobile-backend:verifyIapPurchase`).
- **`pubspec.yaml`** — added `in_app_purchase_android: ^0.5.0` (direct import for base-plan handling).
- **Play Console** (done by client): created `swan_premium` + 3 active base plans, deactivated the 3
  old separate subscriptions. Granted Play Developer API access to the SA (View financial data +
  Manage orders). **Enabled `androidpublisher.googleapis.com`** on the `swan-match` Cloud project.
- **Why one-subscription-with-base-plans matters:** separate Play subscriptions let one Google
  account stack monthly + yearly = double billing. Base plans within one subscription are mutually
  exclusive (switching = upgrade/downgrade). iOS already correct via subscription group.

### 3.2 Apple Sign-In
- **Root cause** of the failure was configuration, not code: the **Sign in with Apple capability**
  (App ID) and **Firebase Apple provider** were not enabled. Both are now **enabled and verified**:
  - App ID `com.swanmatch.app` → Sign In with Apple capability ✅
  - Firebase → Authentication → Apple provider Enabled ✅ (Services ID correctly blank for native iOS)
  - `ios/Runner/Runner.entitlements` has `com.apple.developer.applesignin` ✅
  - Build 5/6 signed with that entitlement; profile "SwanMatch App Store" grants it ✅
  - Bundle ID matches Firebase iOS app (`GOOGLE_APP_ID 1:439342747193:ios:4a30bfb500aeaabc18c7e8`) ✅
  - Nonce code (`signInWithApple` in `auth_service.dart`) is the correct standard pattern ✅
- **Fixed misleading error**: Apple failures no longer show "Invalid email or password" — now show an
  Apple-specific message (login + signup pages).
- **TEMP DIAGNOSTIC (build 6, REMOVE before prod):** the Apple `FirebaseAuthException` handler in
  `custom_login_page.dart` shows the exact `code` + `message` on screen; `signInWithApple` throws a
  clear `apple-null-identity-token` if Apple returns no token.
- **Status:** Simulator always fails (`invalid-credential` / "Invalid OAuth response from apple.com")
  — a known iOS Simulator + Firebase limitation. **But the friend reports it also fails on a REAL
  device.** App Check is **Monitoring (not enforced)** → ruled out as the blocker. **Unresolved** —
  build 6's on-screen diagnostic will reveal the true real-device error code (next step).

### 3.3 Chat
- **Read receipts (single vs double tick) — FIXED:**
  - `lib/models/message_model.dart` — added `seen` (bool, default false) to model + `toMap`/`fromMap`.
  - `lib/services/chat_service.dart` — added `markMessagesSeen(otherUserId)`: batch-sets `seen:true`
    on messages addressed to the current user. (Firestore rules already allow chat participants to
    write messages — no rules change needed.)
  - `lib/features/auth/presentation/pages/chat_conversation_page.dart` — calls `markMessagesSeen` on
    chat open and when new incoming messages arrive; tick rendering now:
    clock = sending, **single ✓ = delivered (not seen)**, **blue ✓✓ (`0xFF34B7F1`) = seen**.
- **Online/offline status — intentionally NOT changed** (per instruction). Existing logic in
  `main.dart` (`didChangeAppLifecycleState`) sets online on `resumed`, offline on `paused/detached`.
  Known minor edge: cold start marks online only after first foreground event (not changed).

### 3.4 Build / release fixes & gotchas
- **App Store upload rejected — x86_64 (simulator) slice in `objective_c.framework`** (pulled by
  `in_app_purchase_storekit`, a Dart native-assets framework). Running on a Simulator builds the
  x86_64 slice; **Xcode's "Archive" button embeds it** → Apple rejects (codes 90086/91169/90203/90087).
  **Fix: build with `flutter build ipa` (NOT Xcode Archive)** → produces arm64-only. Verify with
  `lipo -info`. After any simulator run, clean before a device build.
- **Build number reverting** to old value → fixed by bumping pubspec `+N` (so any flutter cmd
  regenerates the correct number).
- **`codesign` keychain dialog** blocks `flutter build ipa` mid-run → must click **"Always Allow"**.
- All documented in `~/Desktop/Path/Instructions/24-iap-store-gotchas.md` (MAJOR/MINOR + checklist).

### 3.5 Marketing assets
- App Store screenshots resized to **1284×2778** (6.5"): `~/Desktop/Swan needs/screens/appstore_6.5_framed/`
  (`01_find_your_person`, `02_verified_profiles`, `03_start_chatting`, `04_make_your_match`).
- Edited framed-mockup text ("Salem, India"→"Georgia, US", "Harirajan N"→"Max") via Pillow.

---

## 4. Pending / Next Steps

1. **Upload iOS build 6** via Transporter (`build/ios/ipa/Swan Match.ipa`).
2. **Friend tests Continue with Apple on a REAL device (build 6)** → screenshot the exact red-banner
   error → diagnose the real Apple failure.
3. **Build Android v11** with the chat tick fix:
   `flutter build appbundle --release --build-number=11` → upload to internal testing.
4. **Android IAP test purchase** (device whose Gmail is a Play **License tester**; cancel any existing
   test sub first) → confirm `verifyIapPurchase` fires with correct tier and premium/badge appear.
5. **Remove the temporary Apple diagnostic** (on-screen error code + null-token throw) before prod.
6. App Store listing finish: attach build, App Privacy nutrition label, screenshots (ready), age
   rating already set to 18+.
7. **Security:** rotate chat-exposed keys (APNs `.p8`, App Store IAP `.p8` on Desktop), ensure no
   `firebase-service-account.json` in git history.

---

## 5. Key Files

| File | Purpose |
|---|---|
| `lib/services/iap_service.dart` | Platform-aware IAP (iOS products / Android base plans), auto-restore |
| `lib/services/chat_service.dart` | Messaging + `markMessagesSeen` (read receipts) |
| `lib/models/message_model.dart` | Message model incl. `seen` |
| `lib/features/auth/presentation/pages/chat_conversation_page.dart` | Chat UI, tick rendering, presence stream |
| `lib/features/auth/presentation/pages/subscription_page.dart` | Subscription UI (wires IapService) |
| `lib/features/auth/presentation/pages/custom_login_page.dart` / `custom_signup_page.dart` | Auth UI + Apple handler (temp diagnostic) |
| `lib/services/auth_service.dart` | `signInWithApple` (nonce), `readableAuthError` |
| `lib/main.dart` | App init, App Check, online/offline lifecycle |
| `functions/index.js` | `verifyIapPurchase` (Apple + Google receipt verification) |
| `firestore.rules` | Chat messages: participants can read/write |
| `ios/Runner/Runner.entitlements` | aps-environment=production, applesignin |

---

## 6. Useful Commands

```bash
export PATH="$PATH:/Users/apple/flutter/bin"

# Android release AAB (bump build number each upload; Android is at 10 → next 11)
flutter build appbundle --release --build-number=11
#   → build/app/outputs/bundle/release/app-release.aab

# iOS device IPA (ALWAYS use this, not Xcode Archive — avoids x86_64 slice)
rm -rf .dart_tool build ios/.symlinks        # clean after any simulator run
flutter pub get
flutter build ipa --release                  # build number from pubspec (+6)
#   → build/ios/ipa/Swan Match.ipa  → upload via Transporter app
# (click "Always Allow" on the codesign keychain dialog if it appears)

# Verify iOS IPA is arm64-only (must NOT contain x86_64)
unzip -q "build/ios/ipa/Swan Match.ipa" -d /tmp/ipa
lipo -info "/tmp/ipa/Payload/Runner.app/Frameworks/objective_c.framework/objective_c"

# Deploy the IAP verification function
firebase deploy --only functions:mobile-backend:verifyIapPurchase

# Tail IAP verification logs during a test purchase
firebase functions:log --only verifyIapPurchase

# Set iOS build number explicitly (if needed) without full build
flutter build ios --config-only --build-number=6
```

---

## 7. Gotchas Reference (see `~/Desktop/Path/Instructions/24-iap-store-gotchas.md`)
- Firebase Analytics auto-adds `AD_ID` permission → remove via `tools:node="remove"` + declare "No".
- Android plans must be base plans of ONE subscription (else double-billing).
- Owned subs need auto-restore to grant premium.
- Subscriptions billed per store account, not app email.
- Google Sign-In error 10 = missing Play App Signing SHA-1 in Firebase.
- iOS x86_64 archive rejection → `flutter build ipa`, not Xcode Archive.
- License testers (Android) / TestFlight (iOS) → free IAP testing.
