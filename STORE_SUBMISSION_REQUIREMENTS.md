# Swan Match — App Store & Google Play Submission Requirements

This document lists everything required to publish the Swan Match mobile app to the
**Apple App Store** and **Google Play Store**. Items are marked:

- ✅ **Done** — already in place
- ⚠️ **Action needed** — must be completed before submission
- 🔴 **Blocker** — will cause rejection if not resolved first

---

## 0. Two critical blockers to resolve first 🔴

These two items will get the app **rejected** by both stores and must be fixed before anything else.

### 🔴 1. In-app payments must use Apple / Google billing (currently Stripe)
The app currently unlocks Premium through **Stripe**. Both stores **prohibit** this for digital
subscriptions sold inside a mobile app:
- **Apple** (Guideline 3.1.1): digital subscriptions **must** use Apple In-App Purchase (StoreKit). Stripe is only allowed for physical goods/services.
- **Google Play**: digital goods **must** use Google Play Billing.

**What this means:** the iOS and Android apps need **native in-app purchase** added for the Premium
plans (Stripe can stay for the website/admin). This is development work and should be planned for.
*(Flutter's `in_app_purchase` package supports both stores.)*

### 🔴 2. App identifier is still the default placeholder
Both platforms currently use a template ID:
- iOS bundle ID: `com.example.swamMatchApp`
- Android package: `com.example.swam_match_app`

Stores **reject any app using `com.example`**. These must be changed to a real, permanent
reverse-domain ID (e.g. `com.swanmatch.app`) **before the first upload** — it can never be changed
later, so it must be decided once. *(Note the current value also has a typo: "swam" → "swan".)*

---

## 1. Developer accounts & fees ⚠️

| Need | Apple App Store | Google Play |
|---|---|---|
| Account | Apple Developer Program | Google Play Developer account |
| Cost | **$99 / year** | **$25 one-time** |
| Identity | Enroll as **organization** (Swan Match, Inc.) → requires a **D-U-N-S number** (free, ~1–2 weeks) | Organization account; Google now requires **identity & D-U-N-S verification** for new orgs |
| Build tooling | A **Mac with Xcode** (or a Mac CI service) to archive the iOS build | Any machine (Flutter builds the Android bundle) |

> Dating apps are sometimes asked for extra verification on Google Play — budget a little extra time.

---

## 2. Technical / build requirements ⚠️

- 🔴 Final **app ID** chosen (see blocker #2).
- ⚠️ **Signing**: iOS distribution certificate + provisioning profile; Android upload key (or Play App Signing).
- ⚠️ **Release builds**: iOS `.ipa` (archived in Xcode) and Android `.aab` (app bundle).
- ⚠️ **iOS push notifications**: upload an **APNs Auth Key** to Firebase so notifications work on iPhone.
- ⚠️ **Version & build numbers** set (e.g. 1.0.0 / build 1).
- ✅ Firebase configured for production (project `swan-match`).
- ✅ Minimum versions OK (iOS 13+).
- ⚠️ Test the **release** build on **real devices** (not just debug/emulator).

---

## 3. Store listing assets (both stores) ⚠️

- **App name**: Swan Match · short subtitle/tagline.
- **Description** + **keywords**.
- **App icon**: 1024×1024 (Apple), 512×512 (Play).
- **Screenshots**: multiple sizes — iPhone 6.7" & 6.5" (and iPad if supported); Android phone (and tablet if supported).
- **Feature graphic** (Play, 1024×500). App preview video optional.
- **Category**: Lifestyle / Social.
- **Support URL**, **Marketing URL**, **Privacy Policy URL** (✅ already live at swan-match.com/privacy).
- **Contact email** for store communication.

---

## 4. Legal & privacy compliance

| Requirement | Status |
|---|---|
| Privacy Policy (public URL) | ✅ Done (`/privacy`) |
| Terms of Service / EULA | ✅ Done (`/terms`) |
| Refund & Subscription terms | ✅ Done (`/subscription`, `/refund`) |
| **In-app account deletion** (Apple & Google both require it) | ✅ Done (Settings → Delete Account) |
| Community Guidelines / Safety | ✅ Done (`/guidelines`, `/safety`) |
| **Apple "App Privacy" labels** (declare data collected) | ⚠️ Fill in App Store Connect |
| **Google "Data Safety" form** (declare data collected/shared) | ⚠️ Fill in Play Console |
| **Age rating**: 18+ / Mature (dating) | ⚠️ Complete the rating questionnaire |

---

## 5. Dating-app-specific requirements (Apple is strict) ⚠️

- **Age gate 18+** — ✅ app collects date of birth and blocks under-18.
- **User-content safety (Apple Guideline 1.2)** — apps with user content must have: a way to **report**, a way to **block**, **moderation**, and a content agreement (EULA) with **zero tolerance for objectionable content**. ✅ All present (report, block, admin moderation queue, 24h review).
- **Demo / test account for reviewers** — because the app requires login, you **must** give Apple (and often Google) a **working test account** (email + password, pre-verified, ideally with Premium enabled) in the review notes. ⚠️ Prepare one.
- **Originality (Apple Guideline 4.3)** — the dating category is crowded; the app should look polished and distinct to avoid a "spam/duplicate" rejection.

---

## 6. Pre-submission testing ⚠️

- **Apple TestFlight** beta + **Google Play internal/closed testing** before going live.
- Verify: sign-up, login (email + Google), photo upload, matching, chat, notifications, **purchase flow (via store billing)**, account deletion — all on real devices.
- No crashes on supported OS versions.

---

## 7. What's already done vs. what's needed — summary

**✅ Already done (no client action):**
- Backend, Firebase, security rules, admin dashboard
- All legal pages (Privacy, Terms, Subscription, Refund, Guidelines, Safety, Data Deletion)
- In-app account deletion (store-required)
- Reporting, blocking, moderation (UGC safety)
- 18+ age gate

**⚠️ Needs to be done before submission:**
1. 🔴 **Add native in-app purchase** (Apple IAP + Google Play Billing) for Premium
2. 🔴 **Change the app ID** from `com.example.*` to a real permanent ID
3. Open **Apple ($99/yr)** and **Google Play ($25)** developer accounts (+ D-U-N-S for the company)
4. Create **store listing assets** (icon, screenshots, descriptions)
5. Configure **iOS push (APNs key)** + signing certificates
6. Fill **App Privacy labels** (Apple) and **Data Safety form** (Google)
7. Complete **age rating** questionnaires
8. Prepare a **demo/test account** for reviewers
9. **Beta test** (TestFlight / Play internal) → then submit

---

## 8. Rough timeline & cost (for planning)

| Item | Time | Cost |
|---|---|---|
| Apple Developer + D-U-N-S | 1–2 weeks (D-U-N-S can be slow) | $99/yr |
| Google Play Developer + verification | 2–7 days | $25 once |
| Add in-app purchase (both stores) | **development work** — plan accordingly | — |
| Change app ID + re-test | ~1 day | — |
| Listing assets (icon, screenshots, copy) | 2–4 days | design time |
| Review wait (after submit) | Apple ~1–3 days · Google ~1–7 days | — |

> The two 🔴 blockers (in-app purchase + app ID) are the critical path. Everything else can proceed in parallel.

---

*Prepared as a submission-readiness checklist for the Swan Match mobile app (iOS & Android).*
