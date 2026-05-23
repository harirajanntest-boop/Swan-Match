# Security Hardening Start Plan

## Summary
Start with the highest-risk, easiest-to-abuse areas in this Firebase/Flutter app: Firestore rules, Storage rules, Cloud Function callable abuse, App Check, and account/report controls. The first goal is to stop users from editing privileged fields, reading unnecessary sensitive profile data, uploading unsafe files, or abusing callable functions.

## Key Changes
- Tighten Firestore rules:
  - Restrict `/users/{userId}` owner writes so normal users cannot change admin/security/payment fields like `account`, `subscriptionPlan`, `subscriptionStatus`, `isVerified`, `verificationStatus`, `stripeCustomerId`, or moderation fields.
  - Restrict `/profileViews` so only involved users or admins can read relevant records.
  - Lock `/user_lookup` down; signed-in users should not freely read/write all lookup records.
  - Validate `/reports` creates: no self-reporting, required category/reason, max text length, server-friendly status fields.
  - Validate chat/message writes so `senderId` must equal `request.auth.uid`, `receiverId` must be a participant, and users cannot forge messages for others.

- Tighten Storage rules:
  - Limit profile/verification uploads to owner-only paths.
  - Allow only image MIME types.
  - Add max file size limits.
  - Separate public profile photos from sensitive verification uploads; verification files should not be readable by all signed-in users.

- Harden Cloud Functions:
  - Add reusable rate-limit helper for callable functions using Firestore counters.
  - Apply limits first to `checkPhoneExists`, `checkAuthProviders`, `createCheckoutSession`, `verifySubscription`, `getStripePrices`, and especially `sendNotification`.
  - Replace or restrict `sendNotification`; current behavior lets any signed-in user send a push notification to any FCM token.
  - Stop logging sensitive/debug payment details such as secret prefixes and verbose webhook secret checks.

- Enable platform protections:
  - Enable Firebase App Check for Firestore, Storage, and Functions.
  - Use Play Integrity for Android, App Attest/DeviceCheck for iOS, and reCAPTCHA for web if web remains enabled.
  - Ensure Firebase Auth email enumeration protection and phone auth abuse protections are enabled in Firebase console.

## Easy First Tasks
- Update `.gitignore` is already good for `.env`; confirm `.env` was never committed.
- Remove sensitive debug logs from `functions/index.js`.
- Add Storage file type and size checks.
- Add `reportedUid != request.auth.uid` and required report category validation.
- Restrict `profileViews` read access.
- Disable or admin-gate `sendNotification`.

## Test Plan
- Use Firebase Emulator tests for Firestore and Storage rules:
  - Normal user cannot set their own `subscriptionPlan`, `account`, `isVerified`, or `verificationStatus`.
  - User can still edit safe profile fields.
  - User cannot read another user’s verification uploads.
  - User cannot create a message with fake `senderId`.
  - User cannot self-report.
  - User cannot read/write arbitrary `user_lookup` docs.
- Manually test app flows after rule changes:
  - Signup/onboarding.
  - Profile edit.
  - Photo upload.
  - Report/block user.
  - Send message.
  - Subscription checkout.
  - Account deletion.

## Assumptions
- Keep Firebase as the backend.
- Do security hardening in small steps so the app does not break suddenly.
- Prioritize launch/app-store safety over perfect enterprise security.
- Admin access should eventually move from hardcoded emails in rules to custom Firebase Auth claims.
