import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../features/auth/presentation/pages/custom_login_page.dart';
import '../../services/user_service.dart';

/// Handles blocked access for users with `account: Suspended` in Firestore.
class AccountSuspensionHelper {
  AccountSuspensionHelper._();

  static const String message =
      'Your account has been suspended due to your actions. '
      'For more information, contact swanmatch.com.';

  static Future<bool> isCurrentUserSuspended() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final profile = await UserService.instance.getUserProfile(uid);
    return UserService.instance.isAccountSuspended(profile);
  }

  /// Signs out and shows the suspension dialog. Returns `true` if blocked.
  static Future<bool> blockIfSuspended(BuildContext context) async {
    if (!await isCurrentUserSuspended()) return false;

    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.onyx,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Account Suspended', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          message,
          style: TextStyle(color: Colors.white70, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'OK',
              style: TextStyle(color: AppColors.goldMedium),
            ),
          ),
        ],
      ),
    );

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const CustomLoginPage()),
        (route) => false,
      );
    }
    return true;
  }
}
