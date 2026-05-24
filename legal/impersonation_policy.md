# SWAN MATCH — IMPERSONATION & FAKE PROFILE POLICY
*Last Updated: May 25, 2026*

Swan Match is dedicated to facilitating authentic, premium, and safe matches. To maintain the highest standards of trust and safety, we enforce a zero-tolerance policy against identity theft, catfishing, impersonation, and fake accounts. 

Any account found violating this policy will be immediately suspended, permanently banned, and blocked from re-registering on our platform.

---

## 1. Prohibited Activities

Users of Swan Match are strictly prohibited from engaging in the following actions:

- **Catfishing:** Creating a profile using photos, names, or biography details belonging to another real person (whether a celebrity, public figure, or private individual) to deceive or mislead others.
- **Identity Impersonation:** Pretending to be someone else, or falsely claiming an affiliation with an organization, business, or entity.
- **Stock & AI Photo Abuse:** Using stock photos, internet-downloaded images, or AI-generated faces to represent a personal profile. All profile photos must represent the actual user.
- **Sugar-Daddy & Financial Scams:** Registering accounts to solicit money, request cryptocurrency, facilitate financial transactions, or promise financial support (e.g., sugar-daddy/sugar-baby profiles, investment pitches).
- **Multiple Accounts:** Users may only maintain one active profile on the platform. Duplicate profiles registered by the same individual will be flagged and auto-merged or deleted.

---

## 2. Detection & Mitigation Protocols

We protect the platform from impersonation and fake accounts using active, state-of-the-art backend safety controls:

- **Photo Hash Matching:** When a photo is uploaded, our server registers its hash (completing Step 17 photo check). If a photo matches an existing profile's hash, both accounts are immediately flagged for duplicate photo checks.
- **Signup Velocity Throttling:** We track IP creation rates. If multiple signups originate from a single IP within a short period, the accounts are instantly flagged for manual administrative review.
- **Facial Photo Verification:** Users are encouraged or required to verify their profiles by submitting a selfie that matches their uploaded profile images, verified by our moderation team.

---

## 3. Reporting & Enforcement

- **In-App Reporting:** If you believe a profile is fake or impersonating someone, tap the "Report" button on their profile or chat. Select the "Fake Profile / Catfish / Impersonation" category.
- **Verification Appeals:** If your account was suspended under suspicion of impersonation, you can submit an appeal directly from the app (using the `submitAppeal` Callable function) by uploading valid government-issued photo identification to verify your real identity.
- **Administrative Action:** Admins review all flagged duplicate reports on the Web Admin Dashboard. Verified imposters are banned, and their hardware device fingerprints (device UUIDs) are logged in the secure connection records to block future signups.
