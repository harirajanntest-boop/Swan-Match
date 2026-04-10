import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_service.dart';

class AuthService {
	AuthService._();

	static final AuthService instance = AuthService._();

	final FirebaseAuth _auth = FirebaseAuth.instance;
	String? _verificationId;
	int? _resendToken;
	static const String _emailLinkPrefKey = 'email_link_sign_in_email';

	Stream<User?> get authStateChanges => _auth.authStateChanges();

	User? get currentUser => _auth.currentUser;

	Future<void> sendOtp({required String phoneNumber}) async {
		final normalizedPhone = normalizePhoneE164(phoneNumber);
		final completer = Completer<void>();

		await _auth.verifyPhoneNumber(
			phoneNumber: normalizedPhone,
			forceResendingToken: _resendToken,
			verificationCompleted: (credential) async {
				if (!completer.isCompleted) {
					completer.complete();
				}
			},
			verificationFailed: (error) {
				if (!completer.isCompleted) {
					completer.completeError(error);
				}
			},
			codeSent: (verificationId, resendToken) {
				_verificationId = verificationId;
				_resendToken = resendToken;
				if (!completer.isCompleted) {
					completer.complete();
				}
			},
			codeAutoRetrievalTimeout: (verificationId) {
				_verificationId = verificationId;
			},
			timeout: const Duration(seconds: 60),
		);

		await completer.future;
	}

	PhoneAuthCredential createPhoneCredential(String otpCode) {
		if (_verificationId == null) {
			throw FirebaseAuthException(
				code: 'missing-verification-id',
				message: 'OTP session expired. Please request OTP again.',
			);
		}

		return PhoneAuthProvider.credential(
			verificationId: _verificationId!,
			smsCode: otpCode,
		);
	}

	Future<UserCredential> signInWithPhoneOtp(String otpCode) async {
		final credential = createPhoneCredential(otpCode);
		return await _auth.signInWithCredential(credential);
	}

	Future<void> registerWithEmailAndPhone({
		required String email,
		required String password,
		required String otpCode,
		required Map<String, dynamic> profileSeed,
	}) async {
		final credential = createPhoneCredential(otpCode);
		final userCredential = await _auth.createUserWithEmailAndPassword(
			email: email.trim(),
			password: password,
		);

		await userCredential.user?.linkWithCredential(credential);

		final user = _auth.currentUser;
		if (user == null) {
			throw FirebaseAuthException(
				code: 'registration-failed',
				message: 'Could not create user session after registration.',
			);
		}

		await UserService.instance.upsertUserProfile(
			uid: user.uid,
			data: <String, dynamic>{
				...profileSeed,
				'uid': user.uid,
				'email': email.trim(),
				'phoneNumber': user.phoneNumber ?? profileSeed['phoneNumber'] ?? '',
				'createdAt': DateTime.now(),
				'updatedAt': DateTime.now(),
			},
		);
	}

	Future<void> loginWithEmailAndVerifiedPhoneOtp({
		String? email,
		required String password,
		required String otpCode,
		required String phoneNumber,
	}) async {
		final normalizedPhone = normalizePhoneE164(phoneNumber);

		final phoneCredential = createPhoneCredential(otpCode);
		final tempPhoneSession = await _auth.signInWithCredential(phoneCredential);
		final tempUid = tempPhoneSession.user?.uid;
		final verifiedPhone = tempPhoneSession.user?.phoneNumber;

		String loginEmail = (email ?? '').trim();
		if (loginEmail.isEmpty) {
			if (tempUid == null) {
				await _auth.signOut();
				throw FirebaseAuthException(
					code: 'missing-email',
					message: 'Unable to resolve account email from verified phone login.',
				);
			}

			final profile = await UserService.instance.getUserProfile(tempUid);
			loginEmail = (profile?['email'] ?? '').toString().trim();
			if (loginEmail.isEmpty) {
				await _auth.signOut();
				throw FirebaseAuthException(
					code: 'missing-email',
					message: 'This account does not have an email for password login.',
				);
			}
		}

		await _auth.signOut();

		await _auth.signInWithEmailAndPassword(
			email: loginEmail,
			password: password,
		);

		final loggedUser = _auth.currentUser;
		if (loggedUser == null) {
			throw FirebaseAuthException(
				code: 'login-failed',
				message: 'Unable to complete login.',
			);
		}

		final storedProfile = await UserService.instance.getUserProfile(loggedUser.uid);
		final storedPhone = (storedProfile?['phoneNumber'] ?? '').toString();

		final normalizedStored = _tryNormalize(storedPhone);
		final normalizedVerified = _tryNormalize(verifiedPhone ?? '');

		final phoneMatches =
				normalizedVerified.isNotEmpty &&
				(normalizedVerified == normalizedPhone || normalizedVerified == normalizedStored);

		if (!phoneMatches) {
			await _auth.signOut();
			throw FirebaseAuthException(
				code: 'phone-mismatch',
				message: 'Phone OTP verified for different phone number.',
			);
		}
	}

	Future<void> validateEmailPassword({
		required String email,
		required String password,
	}) async {
		await _auth.signInWithEmailAndPassword(
			email: email.trim(),
			password: password,
		);
		await _auth.signOut();
	}

	Future<void> ensureEmailRegistered({required String email}) async {
		final trimmedEmail = email.trim().toLowerCase();
		if (trimmedEmail.isEmpty) {
			throw FirebaseAuthException(
				code: 'invalid-email',
				message: 'Email is required.',
			);
		}

		final methods = await _auth.fetchSignInMethodsForEmail(trimmedEmail);
		if (methods.isEmpty) {
			throw FirebaseAuthException(
				code: 'user-not-found',
				message: 'No account found for this email.',
			);
		}

		if (!methods.contains('password')) {
			throw FirebaseAuthException(
				code: 'operation-not-allowed',
				message: 'Password sign-in is not enabled for this account.',
			);
		}
	}

	Future<void> sendPasswordReset({required String email}) async {
		await _auth.sendPasswordResetEmail(email: email.trim());
	}

	ActionCodeSettings _emailLinkSettings() {
		return ActionCodeSettings(
			url: 'https://swan-match.firebaseapp.com',
			handleCodeInApp: true,
			androidPackageName: 'com.example.swam_match_app',
			androidInstallApp: true,
			androidMinimumVersion: '1',
			iOSBundleId: 'com.example.swamMatchApp',
		);
	}

	Future<void> sendEmailSignInLink({required String email}) async {
		final trimmedEmail = email.trim().toLowerCase();
		if (trimmedEmail.isEmpty) {
			throw FirebaseAuthException(
				code: 'invalid-email',
				message: 'Email is required to send a sign-in link.',
			);
		}

		await _auth.sendSignInLinkToEmail(
			email: trimmedEmail,
			actionCodeSettings: _emailLinkSettings(),
		);

		final prefs = await SharedPreferences.getInstance();
		await prefs.setString(_emailLinkPrefKey, trimmedEmail);
	}

	bool isEmailLink(String link) {
		return _auth.isSignInWithEmailLink(link);
	}

	Future<UserCredential> completeEmailLinkSignIn(String link) async {
		if (!isEmailLink(link)) {
			throw FirebaseAuthException(
				code: 'invalid-email-link',
				message: 'Invalid or expired email sign-in link.',
			);
		}

		final prefs = await SharedPreferences.getInstance();
		final email = (prefs.getString(_emailLinkPrefKey) ?? '').trim();
		if (email.isEmpty) {
			throw FirebaseAuthException(
				code: 'missing-email-otp',
				message: 'Email is required to complete sign-in.',
			);
		}

		final credential = await _auth.signInWithEmailLink(
			email: email,
			emailLink: link,
		);

		await prefs.remove(_emailLinkPrefKey);
		return credential;
	}

	Future<void> signOut() => _auth.signOut();

	String readableAuthError(Object error) {
		if (error is FirebaseAuthException) {
			switch (error.code) {
				case 'invalid-verification-code':
					return 'Invalid OTP code. Please check the SMS code and try again.';
				case 'session-expired':
					return 'OTP expired. Please request a new OTP.';
				case 'missing-email-otp':
					return 'Email OTP session expired. Please request OTP again.';
				case 'email-mismatch':
					return 'The OTP does not match the selected email login account.';
				case 'invalid-phone-number':
					return 'Invalid phone number. For India, enter exactly 10 digits (example: 6382070945).';
				case 'user-not-found-with-phone':
					return 'No account found with this phone number.';
				case 'too-many-requests':
					return 'Too many OTP attempts. Please wait and try again later.';
				case 'quota-exceeded':
					return 'SMS quota exceeded for this Firebase project. Please try later or use test phone numbers.';
				case 'captcha-check-failed':
					return 'App verification failed. Please retry on a real device with Play Services.';
				case 'operation-not-allowed':
					return 'Phone authentication is not enabled in Firebase Console.';
				case 'missing-email-otp-config':
					return 'Email OTP is not configured. Set SMTP dart-defines and restart the app.';
				default:
					if ((error.message ?? '').isNotEmpty) {
						return error.message!;
					}
			}
		}

		return error.toString();
	}

	String normalizePhoneE164(String value, {String defaultCountryCode = '+91'}) {
		var raw = value.trim();
		if (raw.isEmpty) {
			throw FirebaseAuthException(
				code: 'invalid-phone-number',
				message: 'Phone number is required.',
			);
		}

		raw = raw
				.replaceAll(' ', '')
				.replaceAll('-', '')
				.replaceAll('(', '')
				.replaceAll(')', '');

		String normalized;
		if (raw.startsWith('+')) {
			normalized = '+${raw.substring(1).replaceAll(RegExp(r'[^0-9]'), '')}';
		} else if (raw.startsWith('00')) {
			normalized = '+${raw.substring(2).replaceAll(RegExp(r'[^0-9]'), '')}';
		} else {
			var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');

			if (digits.startsWith('0') && digits.length > 10) {
				digits = digits.substring(1);
			}

			if (digits.length == 10) {
				final ccDigits = defaultCountryCode.replaceAll(RegExp(r'[^0-9]'), '');
				normalized = '+$ccDigits$digits';
			} else if (digits.startsWith('91') && digits.length == 12) {
				normalized = '+$digits';
			} else {
				normalized = '+$digits';
			}
		}

		if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(normalized)) {
			throw FirebaseAuthException(
				code: 'invalid-phone-number',
				message:
					'Invalid phone number format. Use digits only (for India: 10 digits, e.g. 6382070945).',
			);
		}

		if (normalized.startsWith('+91')) {
			final local = normalized.substring(3);
			if (local.length != 10) {
				throw FirebaseAuthException(
					code: 'invalid-phone-number',
					message:
						'Indian phone number must be exactly 10 digits (without +91).',
				);
			}
		}

		return normalized;
	}

	String _tryNormalize(String value) {
		try {
			return normalizePhoneE164(value);
		} catch (_) {
			return '';
		}
	}
}
