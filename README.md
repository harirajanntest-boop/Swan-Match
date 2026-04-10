# swam_match_app

Flutter matrimonial app with Firebase backend integration.

## Firebase Setup

1. Install FlutterFire CLI (already available in your environment):

```bash
dart pub global activate flutterfire_cli
```

2. Configure Firebase for this project:

```bash
flutterfire configure
```

3. Add generated app config files:
- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`

4. Deploy Firestore rules from this repo:

```bash
firebase deploy --only firestore:rules
```

## Implemented Backend

- Firebase Auth with:
	- Email + password
	- Phone OTP verification
	- Login OTP delivery by channel:
		- Email login (`email + password`) sends OTP to email
		- Phone login (`phone + password`) sends OTP by SMS
	- Mandatory dual verification for login flow (password + OTP)
- Firestore profile persistence across registration steps.
- Firestore collections and services:
	- `users`
	- `interests`
	- `chats/{chatId}/messages`

## Registration Data Flow

The registration screens now persist data to Firestore in this sequence:

1. Create profile basics (`profileFor`, `motherTongue`)
2. Basic details + OTP (`name`, `email`, `password`, `phoneNumber`)
3. Personal details
4. Religious details
5. Location details
6. Professional details
7. Additional details
8. Partner preferences
9. Interests
10. Lifestyle details
11. Subscription selection and dashboard

## Notes

- `lib/main.dart` initializes Firebase on app start.
- Security rules are in `firestore.rules`.
- Existing UI screens are connected to backend services in `lib/services/`.

## Email OTP Configuration (Required)

To enable email OTP delivery from app code, pass SMTP secrets as `--dart-define` values:

```bash
flutter run \
	--dart-define=SMTP_HOST=smtp.example.com \
	--dart-define=SMTP_PORT=587 \
	--dart-define=SMTP_USERNAME=your_smtp_user \
	--dart-define=SMTP_PASSWORD=your_smtp_password \
	--dart-define=SMTP_FROM_EMAIL=no-reply@example.com \
	--dart-define=SMTP_FROM_NAME="Swam Match"
```

If these are not set, email OTP login will fail with a configuration error.

## Firebase Email Link (Passwordless)

You can use Firebase Email Link instead of SMTP OTP. Enable it in Firebase Console:

1. Firebase Console → Authentication → Sign-in method → **Email link (passwordless)**.
2. Add **Authorized domains** including `swan-match.firebaseapp.com`.
3. Ensure Android app is registered and `google-services.json` is updated.

The app will send a sign-in link to the user’s email and complete sign-in when the link is opened on the same device.
