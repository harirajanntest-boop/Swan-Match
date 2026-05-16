import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/constants/colors.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => 
    _ForgotPasswordPageState();
}

class _ForgotPasswordPageState 
  extends State<ForgotPasswordPage> {

  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // Email validation
  bool _isValidEmail(String email) {
    return RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$'
    ).hasMatch(email.trim());
  }

  Future<void> _handleForgotPassword() async {
    // Validate email field
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _emailError = 'Please enter your email address';
      });
      return;
    }

    if (!_isValidEmail(email)) {
      setState(() {
        _emailError = 'Please enter a valid email address';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _emailError = null;
    });

    try {
      // Securely call the Cloud Function to check authentication providers without triggering Email Enumeration protection
      final callable = FirebaseFunctions.instance.httpsCallable('checkAuthProviders');
      final result = await callable.call({'email': email});
      
      final data = result.data as Map<String, dynamic>;
      final bool exists = data['exists'] ?? false;
      final List<dynamic> rawProviders = data['providers'] ?? [];
      final List<String> methods = rawProviders.cast<String>();

      if (!mounted) return;

      // No account found
      if (!exists || methods.isEmpty) {
        setState(() => _isLoading = false);
        _showDialog(
          icon: Icons.person_off_outlined,
          iconColor: Colors.red,
          title: 'No Account Found',
          message:
            'No Swan Match account exists with '
            'this email address.\n\n'
            'Please check the email or '
            'create a new account.',
          buttonText: 'OK',
          buttonColor: Colors.red,
          onPressed: () => Navigator.pop(context),
        );
        return;
      }

      // Email password account exists — prioritize this even if Google is linked
      if (methods.contains('password')) {
        await FirebaseAuth.instance
          .sendPasswordResetEmail(email: email);

        if (!mounted) return;
        setState(() => _isLoading = false);

        _showDialog(
          icon: Icons.mark_email_read_outlined,
          iconColor: Colors.green,
          title: 'Email Sent!',
          message:
            'A password reset link has been '
            'sent to:\n\n$email\n\n'
            'Check your inbox and spam folder. '
            'The link expires in 1 hour.',
          buttonText: 'Back to Login',
          buttonColor: AppColors.goldMedium,
          onPressed: () {
            Navigator.pop(context); // close dialog
            Navigator.pop(context); // back to login
          },
        );
        return;
      }

      // ONLY Google account exists (no password linked yet)
      if (methods.contains('google.com')) {
        setState(() => _isLoading = false);
        _showDialog(
          icon: Icons.account_circle_outlined,
          iconColor: AppColors.goldMedium,
          title: 'Google Account',
          message:
            'This account uses Google Sign-In. '
            'Please continue with Google or link email login in settings.',
          buttonText: 'Go to Login',
          buttonColor: AppColors.goldMedium,
          onPressed: () {
            Navigator.pop(context); // close dialog
            Navigator.pop(context); // go back to login
          },
        );
        return;
      }

      // ONLY Phone account exists
      if (methods.contains('phone')) {
        setState(() => _isLoading = false);
        _showDialog(
          icon: Icons.phone_outlined,
          iconColor: AppColors.goldMedium,
          title: 'Phone Account',
          message:
            'This account uses phone number '
            'to sign in.\n\n'
            'Please use "Continue with Phone '
            'Number" on the login screen and '
            'enter your OTP to access your account.',
          buttonText: 'Go to Login',
          buttonColor: AppColors.goldMedium,
          onPressed: () {
            Navigator.pop(context);
            Navigator.pop(context);
          },
        );
        return;
      }

    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);

      String message = 'Something went wrong. Try again.';

      if (e.code == 'invalid-email') {
        message = 'Invalid email address format.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. '
          'Please try again later.';
      } else if (e.code == 'network-request-failed') {
        message = 'No internet connection. '
          'Please check your network.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade800,
            duration: Duration(seconds: 4),
          ),
        );
      }

    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  void _showDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String buttonText,
    required Color buttonColor,
    required VoidCallback onPressed,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.onyx,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8),

            // Icon
         // Lock icon
Center(
  child: Container(
    width: 64,
    height: 64,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.goldMedium.withOpacity(0.1),
      border: Border.all(
        color: AppColors.goldMedium.withOpacity(0.3),
        width: 1.5,
      ),
    ),
    child: const Icon(
      Icons.lock_reset_outlined,
      color: AppColors.goldMedium,
      size: 30,
    ),
  ),
),

            SizedBox(height: 16),

            // Title
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: 12),

            // Message
            Text(
              message,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: 24),

            // Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: buttonColor == AppColors.goldMedium
                    ? Colors.black
                    : Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.goldMedium,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const SizedBox(height: 20),

              // Lock icon
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.goldMedium.withOpacity(0.1),
                    border: Border.all(
                      color: AppColors.goldMedium.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_reset_outlined,
                    color: AppColors.goldMedium,
                    size: 30,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Title
              const Center(
                child: Text(
                  "Reset Password",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle
              const Center(
                child: Text(
                  "Enter your registered email address "
                  "and we'll send you a reset link.",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 40),

              // Email label
              const Text(
                "Email Address",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 8),

              // Email field
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
                cursorColor: AppColors.goldMedium,
                onChanged: (_) {
                  if (_emailError != null) {
                    setState(() => _emailError = null);
                  }
                },
                decoration: InputDecoration(
                  hintText: "Enter your email",
                  hintStyle: const TextStyle(
                    color: Colors.white24,
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: _emailError != null
                      ? Colors.red
                      : AppColors.goldMedium,
                    size: 20,
                  ),
                  errorText: _emailError,
                  errorStyle: TextStyle(
                    color: Colors.red.shade300,
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: AppColors.onyx,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Colors.white12,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.goldMedium,
                      width: 1.5,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Colors.red,
                      width: 1,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Colors.red,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Send reset button
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _isLoading
                      ? null
                      : AppColors.goldGradient,
                    color: _isLoading
                      ? const Color(0xFF2A2A2A)
                      : null,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading
                      ? null
                      : _handleForgotPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor:
                        Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white54,
                          ),
                        )
                      : const Text(
                          "Send Reset Link",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Back to login
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: "Remember your password? ",
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 13,
                          ),
                        ),
                        TextSpan(
                          text: "Sign In",
                          style: TextStyle(
                            color: AppColors.goldMedium,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.goldMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
