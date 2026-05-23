import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/colors.dart';
import '../../features/auth/presentation/pages/appeal_form_page.dart';
import '../../features/auth/presentation/pages/custom_login_page.dart';
import '../../services/user_service.dart';

/// Handles blocked access for users with `account: Suspended` in Firestore.
class AccountSuspensionHelper {
  AccountSuspensionHelper._();

  static const String message =
      'Your account has been suspended due to your actions. '
      'You can submit an appeal to request reinstatement.';

  static const String pendingMessage =
      'You have already submitted an appeal. '
      'Please wait for a response from the moderation team.';

  static Future<bool> isCurrentUserSuspended() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final profile = await UserService.instance.getUserProfile(uid, forceRefresh: true);
    return UserService.instance.isAccountSuspended(profile);
  }

  static Future<bool> hasPendingAppeal() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final snapshot = await FirebaseFirestore.instance
        .collection('appeals')
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .get();
    return snapshot.docs.isNotEmpty;
  }

  static Future<bool> _showSuspensionDialog(BuildContext context) async {
    if (!context.mounted) return true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.onyx,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Account Suspended', style: TextStyle(color: Colors.white)),
        content: const Text(
          message,
          style: TextStyle(color: Colors.white70, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AppealFormPage()),
                );
              }
            },
            child: const Text('Submit Appeal', style: TextStyle(color: AppColors.goldMedium)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const CustomLoginPage()),
                  (route) => false,
                );
              }
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );

    return true;
  }

  static Future<bool> _showPendingAppealDialog(BuildContext context) async {
    if (!context.mounted) return true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.onyx,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Appeal Pending', style: TextStyle(color: Colors.white)),
        content: const Text(
          pendingMessage,
          style: TextStyle(color: Colors.white70, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const CustomLoginPage()),
                  (route) => false,
                );
              }
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );

    return true;
  }

  static Future<bool> hasApprovedAppeal() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final snapshot = await FirebaseFirestore.instance
        .collection('appeals')
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'approved')
        .get();
    return snapshot.docs.isNotEmpty;
  }

  static Future<void> showAppealApprovedIfNeeded(BuildContext context) async {
    if (!context.mounted) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (!await hasApprovedAppeal()) return;

    final prefs = await SharedPreferences.getInstance();
    const key = 'appeal_approved_notified';
    if (prefs.getBool(key) == true) return;

    await prefs.setBool(key, true);

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.onyx,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Appeal Approved', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Your appeal has been approved. Welcome back!',
          style: TextStyle(color: Colors.white70, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppColors.goldMedium)),
          ),
        ],
      ),
    );
  }

  static Future<bool> blockIfSuspended(BuildContext context) async {
    if (!await isCurrentUserSuspended()) return false;
    if (!context.mounted) return true;

    if (await hasPendingAppeal()) {
      await _showPendingAppealDialog(context);
    } else {
      await _showSuspensionDialog(context);
    }
    return true;
  }
}
