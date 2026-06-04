import 'package:flutter/material.dart';
import 'package:swam_match_app/core/constants/colors.dart';
import 'package:swam_match_app/services/auth_service.dart';
import 'package:swam_match_app/services/user_service.dart';
import 'custom_login_page.dart';
import 'main_dashboard.dart';
import 'onboarding_flow.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _isSending = false;
  bool _isChecking = false;
  String? _message;

  Future<void> _resendVerification() async {
    setState(() {
      _isSending = true;
      _message = null;
    });
    try {
      await AuthService.instance.sendVerificationEmail();
      setState(() => _message = 'Verification email sent! Check your inbox.');
    } catch (e) {
      setState(() => _message = 'Failed to send. Try again later.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _checkVerification() async {
    setState(() {
      _isChecking = true;
      _message = null;
    });
    try {
      final verified = await AuthService.instance.checkEmailVerified();
      if (verified) {
        if (!mounted) return;
        final user = AuthService.instance.currentUser;
        if (user == null) return;
        final profile = await UserService.instance.getUserProfile(user.uid, forceRefresh: true);
        final completed = profile?['registrationCompleted'] == true;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => completed ? const MainDashboard() : const OnboardingFlow(),
          ),
          (route) => false,
        );
      } else {
        setState(() => _message = 'Email not verified yet. Please check your inbox.');
      }
    } catch (e) {
      setState(() => _message = 'Could not check status. Try again.');
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _signOut() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const CustomLoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mark_email_unread, size: 64, color: AppColors.goldMedium),
                const SizedBox(height: 24),
                const Text(
                  'Verify Your Email',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                const Text(
                  'We sent a verification link to your email. Please verify before using the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : _checkVerification,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.goldMedium,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: _isChecking
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('I\'ve Verified — Continue', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isSending ? null : _resendVerification,
                  child: _isSending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.goldMedium))
                      : const Text('Resend Verification Email', style: TextStyle(color: AppColors.goldMedium)),
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(_message!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: _signOut,
                  child: const Text('Use a different account', style: TextStyle(color: Colors.white38)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
