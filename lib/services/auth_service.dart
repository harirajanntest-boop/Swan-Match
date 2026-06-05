import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'push_notification_service.dart';
import 'user_service.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;
  int? _resendToken;
  OAuthCredential? pendingGoogleCredential;
  String? pendingGoogleEmail;

  // Temporary credentials for delayed sign-in
  OAuthCredential? _temporaryGoogleCredential;
  PhoneAuthCredential? _temporaryPhoneCredential;
  String? _temporaryPhoneNumber;
  String? _temporaryGoogleEmail;
  String? _temporaryGoogleDisplayName;
  String? _temporaryGooglePhotoUrl;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // Getters for temporary credentials
  OAuthCredential? get temporaryGoogleCredential => _temporaryGoogleCredential;
  PhoneAuthCredential? get temporaryPhoneCredential =>
      _temporaryPhoneCredential;
  String? get temporaryPhoneNumber => _temporaryPhoneNumber;
  String? get temporaryGoogleEmail => _temporaryGoogleEmail;
  String? get temporaryGoogleDisplayName => _temporaryGoogleDisplayName;
  String? get temporaryGooglePhotoUrl => _temporaryGooglePhotoUrl;

  // Check if there are pending temporary credentials
  bool get hasPendingCredentials =>
      _temporaryGoogleCredential != null || _temporaryPhoneCredential != null;

  // Clear temporary credentials (call on app exit or when starting fresh)
  void clearTemporaryCredentials() {
    _temporaryGoogleCredential = null;
    _temporaryPhoneCredential = null;
    _temporaryPhoneNumber = null;
    _temporaryGoogleEmail = null;
    _temporaryGoogleDisplayName = null;
    _temporaryGooglePhotoUrl = null;
  }

  Future<void> sendOtp({
    required String phoneNumber,
    String? defaultCountryCode,
  }) async {
    final normalizedPhone = normalizePhoneE164(
      phoneNumber,
      defaultCountryCode: defaultCountryCode ?? '+1',
    );
    final completer = Completer<void>();

    await _auth.verifyPhoneNumber(
      phoneNumber: normalizedPhone,
      forceResendingToken: _resendToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-retrieval on Android — store credential temporarily instead of signing in
        _temporaryPhoneCredential = credential;
        _temporaryPhoneNumber = normalizedPhone;
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      verificationFailed: (FirebaseAuthException error) {
        // Handle error
        debugPrint('Phone verification failed: ${error.message}');
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        // Save verificationId and navigate to OTP screen
        _verificationId = verificationId;
        _resendToken = resendToken;
        // Store phone number for later use
        _temporaryPhoneNumber = normalizedPhone;
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        debugPrint('Auto retrieval timeout');
        _verificationId = verificationId;
      },
      timeout: const Duration(seconds: 60),
    );

    // Note: Browser reCAPTCHA occurs BEFORE completer.future resolve.
    // To avoid reCAPTCHA:
    // 1. Android: Add SHA-1/SHA-256 to Firebase & Enable Play Integrity API in Google Cloud Console.
    // 2. iOS: Configure APNs in Firebase & Add REVERSED_CLIENT_ID to Info.plist URL Schemes.
    await completer.future;
  }

  PhoneAuthCredential createPhoneCredential(String otpCode) {
    if (_verificationId == null) {
      throw FirebaseAuthException(
        code: 'missing-verification-id',
        message:
            'Verification is still in progress. Please wait a moment and try again.',
      );
    }

    return PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: otpCode,
    );
  }

  Future<UserCredential?> signInWithPhoneOtp(String otpCode) async {
    final credential = createPhoneCredential(otpCode);
    // ── NEW FLOW: Store credential temporarily, don't sign in yet ──
    _temporaryPhoneCredential = credential;
    // Return null to indicate delayed sign-in
    return null;
  }

  // New method to complete Firebase sign-in with temporary credentials
  Future<UserCredential> completeDelayedSignIn() async {
    if (_temporaryGoogleCredential != null) {
      final result = await _auth.signInWithCredential(
        _temporaryGoogleCredential!,
      );
      await UserService.instance.syncAuthProviders();
      clearTemporaryCredentials();
      return result;
    } else if (_temporaryPhoneCredential != null) {
      final result = await _auth.signInWithCredential(
        _temporaryPhoneCredential!,
      );
      await UserService.instance.syncAuthProviders();
      clearTemporaryCredentials();
      return result;
    } else {
      throw Exception('No temporary credentials found to complete sign-in');
    }
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

    final sanitizedData = <String, dynamic>{...profileSeed};
    sanitizedData.remove('password');
    sanitizedData.remove('confirmPassword');
    sanitizedData.remove('selectedCountryCode');

    await UserService.instance.upsertUserProfile(
      uid: user.uid,
      data: <String, dynamic>{
        ...sanitizedData,
        'uid': user.uid,
        'email': email.trim(),
        'phoneNumber': user.phoneNumber ?? sanitizedData['phoneNumber'] ?? '',
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
        'isVerified': false,
        'idVerified': false,
        'profileVerified': false,
        'profileApprovalStatus': 'pending',
        'verificationStatus': 'pending',
        'subscriptionPlan': 'free',
        'subscriptionName': 'Free',
        'account': 'active',
      },
    );
    await UserService.instance.syncAuthProviders();
  }

  Future<void> loginWithEmailAndVerifiedPhoneOtp({
    String? email,
    required String password,
    required String otpCode,
    required String phoneNumber,
    String? defaultCountryCode,
  }) async {
    final normalizedPhone = normalizePhoneE164(
      phoneNumber,
      defaultCountryCode: defaultCountryCode ?? '+1',
    );

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

    final storedProfile = await UserService.instance.getUserProfile(
      loggedUser.uid,
    );
    final storedPhone = (storedProfile?['phoneNumber'] ?? '').toString();

    final normalizedStored = _tryNormalize(storedPhone);
    final normalizedVerified = _tryNormalize(verifiedPhone ?? '');

    final phoneMatches =
        normalizedVerified.isNotEmpty &&
        (normalizedVerified == normalizedPhone ||
            normalizedVerified == normalizedStored);

    if (!phoneMatches) {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'phone-mismatch',
        message: 'Phone OTP verified for different phone number.',
      );
    }
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await UserService.instance.syncAuthProviders();
    return result;
  }

  Future<void> validateEmailPassword({
    required String email,
    required String password,
  }) async {
    await signInWithEmailAndPassword(email: email, password: password);
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

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<UserCredential?> signInWithGoogle({bool delayedAuth = false}) async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;

    final auth = await account.authentication;
    final googleCredential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );

    // If a user is already logged in, link the Google credential
    final current = _auth.currentUser;
    if (current != null) {
      final result = await current.linkWithCredential(googleCredential);
      await UserService.instance.syncAuthProviders();
      return result;
    }

    if (delayedAuth) {
      // Store the Google credential and user info for delayed sign-in
      _temporaryGoogleCredential = googleCredential;
      _temporaryGoogleEmail = (account.email ?? '').trim();
      _temporaryGoogleDisplayName = account.displayName;
      _temporaryGooglePhotoUrl = account.photoUrl;

      // Return null to indicate delayed sign-in
      return null;
    } else {
      // Direct Sign In
      final result = await _auth.signInWithCredential(googleCredential);
      await UserService.instance.syncAuthProviders();
      return result;
    }
  }

  Future<UserCredential> linkPendingGoogleCredential() async {
    final current = _auth.currentUser;
    if (current == null) {
      throw Exception('No user logged in to link Google to.');
    }
    if (pendingGoogleCredential == null) {
      throw Exception('No pending Google credential to link.');
    }

    final result = await current.linkWithCredential(pendingGoogleCredential!);
    await UserService.instance.syncAuthProviders();
    pendingGoogleCredential = null;
    pendingGoogleEmail = null;
    return result;
  }

  Future<void> signOut() async {
    try {
      await PushNotificationService.instance.clearTokenForCurrentUser();
    } catch (_) {}
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    return _auth.signOut();
  }

  Future<void> updateEmail(String newEmail) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No active user session. Please login again.',
      );
    }

    await user.updateEmail(newEmail.trim());
    if (user.emailVerified == false) {
      await user.sendEmailVerification();
    }
    await user.reload();
  }

  Future<void> updatePhoneNumberWithOtp(String otpCode) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No active user session. Please login again.',
      );
    }

    final credential = createPhoneCredential(otpCode);
    await user.updatePhoneNumber(credential);
    await user.reload();
  }

  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No active user session. Please login again.',
      );
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'No email found for re-authentication.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  Future<void> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No active user session. Please login again.',
      );
    }

    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw FirebaseAuthException(
        code: 'cancelled',
        message: 'Google sign-in cancelled.',
      );
    }

    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );

    await user.reauthenticateWithCredential(credential);
  }

  Future<void> reauthenticateWithPhoneOtp(String otpCode) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No active user session. Please login again.',
      );
    }

    final credential = createPhoneCredential(otpCode);
    await user.reauthenticateWithCredential(credential);
  }

  // ─── Account Linking ───

  List<String> getLinkedProviderIds() {
    final user = _auth.currentUser;
    if (user == null) return [];
    return user.providerData.map((p) => p.providerId).toList();
  }

  Future<void> linkWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return;

    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in.');

    // ── Validate that the Google email matches the registered email ──
    final googleEmail = account.email.trim().toLowerCase();

    // Get the registered email from Firestore profile or Firebase Auth
    String registeredEmail = '';
    try {
      final profile = await UserService.instance.getUserProfile(user.uid);
      registeredEmail = (profile?['email'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
    } catch (_) {}
    // Fallback to Firebase Auth email
    if (registeredEmail.isEmpty) {
      registeredEmail = (user.email ?? '').trim().toLowerCase();
    }

    if (registeredEmail.isNotEmpty && googleEmail != registeredEmail) {
      // Emails don't match → reject linking
      await _googleSignIn.signOut();
      throw Exception(
        'Email mismatch: Please select your registered email ($registeredEmail). '
        'You selected $googleEmail which does not match your account.',
      );
    }

    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );

    await user.linkWithCredential(credential);
  }

  Future<void> linkWithEmailAndPassword(String email, String password) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in.');

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.linkWithCredential(credential);
  }

  Future<void> linkWithPhoneCredential(PhoneAuthCredential credential) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in.');
    await user.linkWithCredential(credential);
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in.');

    final email = user.email;
    if (email == null) throw Exception('User email not found.');

    // Re-authenticate user
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);

    // Update password
    await user.updatePassword(newPassword);
  }

  String readableAuthError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-verification-code':
          return 'The code you entered is incorrect. Please check and try again.';
        case 'session-expired':
          return 'Your verification code has expired. Please request a new one.';
        case 'missing-verification-id':
          return 'Verification is still loading. Please wait a moment and try again.';
        case 'missing-email-otp':
          return 'Your email verification session expired. Please request a new code.';
        case 'email-mismatch':
          return 'This code does not match your email. Please try again.';
        case 'invalid-phone-number':
          return 'The phone number you entered is not valid. Please enter a 10-digit Indian mobile number.';
        case 'user-not-found-with-phone':
          return 'No account found with this phone number. Please register first.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a few minutes and try again.';
        case 'quota-exceeded':
          return 'We are experiencing high traffic. Please try again in a few minutes.';
        case 'captcha-check-failed':
          return 'Verification failed. Please try again.';
        case 'operation-not-allowed':
          return 'This sign-in method is currently unavailable. Please try another option.';
        case 'missing-email-otp-config':
          return 'Email sign-in is temporarily unavailable. Please use phone or Google to log in.';
        case 'account-exists-with-different-credential':
          return 'An account already exists with this email. Please log in using your phone number or password.';
        case 'wrong-password':
          return 'Incorrect password. Please double-check and try again.';
        case 'user-not-found':
          return 'No account found with this email. Please create an account first.';
        case 'email-already-in-use':
          return 'This email is already registered. Please log in or use a different email.';
        case 'weak-password':
          return 'Your password is too simple. Please use at least 8 characters with letters and numbers.';
        case 'invalid-email':
          return 'The email address you entered is not valid. Please check and try again.';
        case 'network-request-failed':
          return 'No internet connection. Please check your network and try again.';
        case 'user-disabled':
          return 'This account has been suspended. Please contact support.';
        case 'requires-recent-login':
          return 'For security reasons, please log out and log back in before making this change.';
        case 'credential-already-in-use':
          return 'This account is already linked to another profile.';
        case 'provider-already-linked':
          return 'This sign-in method is already connected to your account.';
        case 'invalid-credential':
          return 'Invalid email or password. If you signed up with Google or Apple, please use those options.';
        default:
          break;
      }
    }

    // Generic fallback — never show raw exception text to users
    return 'Something went wrong. Please try again.';
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

  // ─── Login Throttling ─────────────────────────────────────────────────────
  Future<void> checkLoginThrottle(String email) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('trackLoginAttempt')
          .call({'email': email});
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        throw FirebaseAuthException(
          code: 'too-many-requests',
          message: 'Too many login attempts. Please try again in 15 minutes.',
        );
      }
      rethrow;
    }
  }

  Future<void> reportLoginSuccess(String email) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('trackLoginSuccess')
          .call({'email': email});
    } catch (_) {}
  }

  Future<void> reportLoginFailure(String email) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('trackLoginFailure')
          .call({'email': email});
    } catch (_) {}
  }

  // ─── Email Verification ──────────────────────────────────────────────────
  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (!user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  Future<bool> checkEmailVerified() async {
    var user = _auth.currentUser;
    if (user == null) return false;

    // Pull the latest state from the server, then RE-FETCH currentUser.
    // After reload(), the old `user` reference is a stale snapshot whose
    // emailVerified still reads the cached value — only a freshly read
    // currentUser reflects the verification. (This is why the first tap
    // used to say "not verified" and the second tap worked.)
    try {
      await user.reload();
    } catch (_) {}
    user = _auth.currentUser;
    if (user == null) return false;
    if (user.emailVerified) return true;

    // Fallback: force a token refresh and reload once more, then re-read.
    // This makes a single tap enough even if the first reload was slow.
    try {
      await user.getIdToken(true);
      await user.reload();
      user = _auth.currentUser;
    } catch (_) {}
    return user?.emailVerified ?? false;
  }
}

class GoogleNeedsLinkingException implements Exception {
  final String email;

  GoogleNeedsLinkingException({required this.email});
}

/// Thrown when a Google email has no existing account in the app.
class GoogleNoAccountException implements Exception {
  final String email;

  GoogleNoAccountException({required this.email});
}
