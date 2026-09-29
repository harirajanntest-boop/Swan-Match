import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/constants/colors.dart';
import '../../services/auth_service.dart';

/// Account deletion for screens outside Settings (e.g. onboarding, where the
/// user may not have a name yet). Same steps as the Settings flow:
/// re-authenticate → revoke Apple tokens → soft-delete the profile (the
/// server's onUserSoftDeleted removes the login and data) → delete the login
/// → sign out.
///
/// Asks for confirmation first. Returns true once the account is gone and the
/// user is signed out (the caller then navigates to the login page); false if
/// the user cancelled or it failed (an error has been shown).
Future<bool> confirmAndDeleteCurrentAccount(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.onyx,
      title: const Text(
        'Delete Account',
        style: TextStyle(color: Colors.white),
      ),
      content: const Text(
        'This permanently deletes your account and everything you have added '
        'so far. It is immediate and cannot be undone.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text(
            'Delete',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  void showError(Object e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AuthService.instance.readableAuthError(e)),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Re-authenticate first, while the login still exists.
  String? appleAuthCode;
  try {
    final providers = user.providerData.map((p) => p.providerId).toList();
    if (Platform.isIOS && providers.contains('apple.com')) {
      appleAuthCode =
          await AuthService.instance.reauthenticateWithAppleForDeletion();
      if (appleAuthCode == null) return false;
    } else if (providers.contains('password')) {
      final password = await _askPassword(context);
      if (password == null || password.isEmpty) return false;
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
    } else {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return false;
      final googleAuth = await googleUser.authentication;
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        ),
      );
    }
  } catch (e) {
    showError(e);
    return false;
  }

  try {
    if (appleAuthCode != null) {
      await AuthService.instance.revokeAppleToken(appleAuthCode);
    }
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'isDeleted': true,
      'status': 'deleted',
      'deletedAt': FieldValue.serverTimestamp(),
      'scheduledHardDeleteAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      ),
      'firstName': 'Deleted',
      'lastName': 'Account',
      'name': 'Deleted Account',
      'displayName': 'Deleted Account',
      'bio': '',
      'shortBio': '',
      'aboutMe': '',
      'phoneNumber': '',
      'email': '',
      'photoUrl': '',
      'profilePhotoUrl': '',
      'photos': <String>[],
      'isOnline': false,
      'online': false,
      'fcmTokens': <String>[],
      'fcmToken': FieldValue.delete(),
    });
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      // The server-side trigger may already have removed the login; the
      // profile is soft-deleted either way, so this still counts as deleted.
      if (e.code != 'user-not-found' && e.code != 'requires-recent-login') {
        rethrow;
      }
    }
    await AuthService.instance.signOut();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your account has been permanently deleted.'),
        ),
      );
    }
    return true;
  } catch (e) {
    showError(e);
    return false;
  }
}

Future<String?> _askPassword(BuildContext context) async {
  final controller = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.onyx,
      title: const Text(
        'Re-authenticate',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Please enter your password to confirm account deletion.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              enabledBorder: UnderlineInputBorder(
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.goldMedium),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.goldMedium,
          ),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
  // Not disposed here: the dialog's closing animation still uses it.
  return ok == true ? controller.text : null;
}
