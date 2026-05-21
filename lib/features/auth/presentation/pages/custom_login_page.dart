import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swam_match_app/core/constants/colors.dart';
import 'package:swam_match_app/services/auth_service.dart';
import 'package:swam_match_app/services/user_service.dart';
import 'package:swam_match_app/features/auth/presentation/pages/custom_signup_page.dart';
import 'package:swam_match_app/features/auth/presentation/pages/onboarding_flow.dart';
import 'package:swam_match_app/features/auth/presentation/pages/main_dashboard.dart';
import 'package:swam_match_app/shared/helpers/account_suspension_helper.dart';
import 'forgot_password_page.dart';

class CustomLoginPage extends StatefulWidget {
  const CustomLoginPage({super.key});

  @override
  State<CustomLoginPage> createState() => _CustomLoginPageState();
}

class _CustomLoginPageState extends State<CustomLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  DateTime? _selectedDob;

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─── Route user based on Firestore profile status ───
  Future<void> _routeUser(User user) async {
    if (!mounted) return;
    try {
      final profile = await UserService.instance.getUserProfile(user.uid);
      if (!mounted) return;

      if (profile != null &&
          UserService.instance.isAccountSuspended(profile)) {
        await FirebaseAuth.instance.signOut();
        _showError(AccountSuspensionHelper.message);
        return;
      }

      if (profile != null && profile['registrationCompleted'] == true) {
        // User has completed all details → Dashboard
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainDashboard()),
          (route) => false,
        );
      } else {
        // User exists but hasn't completed details → Details filling screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingFlow()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      // On error, default to details screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingFlow()),
        (route) => false,
      );
    }
  }

  // ─── Email / Password Login ───
  Future<void> _handleEmailLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter both email and password.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await AuthService.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        _showError('Login failed. Please try again.');
        return;
      }
      await _routeUser(user);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'user-not-found') {
        try {
          final methods = await FirebaseAuth.instance
              .fetchSignInMethodsForEmail(email);
          if (methods.contains('google.com')) {
            _showError(
              'This email is registered with Google. Please click "Continue with Google".',
            );
            return;
          } else if (methods.contains('apple.com')) {
            _showError(
              'This email is registered with Apple. Please click "Continue with Apple".',
            );
            return;
          }
        } catch (_) {}
      }
      _showError(AuthService.instance.readableAuthError(e));
    } catch (e) {
      if (!mounted) return;
      _showError(AuthService.instance.readableAuthError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Google Sign-In ───
  Future<void> _handleGoogleSignIn() async {
    if (_isGoogleLoading) return;
    setState(() => _isGoogleLoading = true);

    try {
      // Step 1: Complete Google Auth Directly
      final userCredential = await AuthService.instance.signInWithGoogle(delayedAuth: false);
      if (userCredential == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }

      final user = userCredential.user;
      if (user == null) {
        _showError('Failed to get user from Google.');
        return;
      }

      // Step 2: Check if user already has a profile
      final profile = await UserService.instance.getUserProfile(user.uid);

      if (profile != null) {
        // Existing User
        await _routeUser(user);
      } else {
        // New Google User -> Immediately show DOB dialog
        if (!mounted) return;
        await _showGoogleDobDialog(user);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showError(AuthService.instance.readableAuthError(e));
    } catch (e) {
      if (!mounted) return;
      _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _showGoogleDobDialog(User user) async {
    DateTime? tempDob = DateTime.now().subtract(const Duration(days: 365 * 18));
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.onyx,
              title: const Text("Date of Birth", style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "You must be 18 or older to use this app.",
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.obsidian,
                      foregroundColor: AppColors.goldMedium,
                    ),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      "${tempDob!.day}/${tempDob!.month}/${tempDob!.year}",
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: tempDob!,
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppColors.goldMedium,
                                onPrimary: Colors.black,
                                surface: AppColors.onyx,
                                onSurface: Colors.white,
                              ),
                              dialogBackgroundColor: AppColors.obsidian,
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setDialogState(() => tempDob = picked);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: () {
                    final age = _calculateAge(tempDob!);
                    if (age < 18) {
                      Navigator.pop(context, false);
                      _showError("You must be 18 or older to use this app.");
                    } else {
                      _selectedDob = tempDob;
                      Navigator.pop(context, true);
                    }
                  },
                  child: const Text("Continue", style: TextStyle(color: AppColors.goldMedium)),
                ),
              ],
            );
          }
        );
      }
    );

    if (result == true && _selectedDob != null) {
      // Valid Age -> Create profile and route
      final age = _calculateAge(_selectedDob!);
      final googlePhoto = user.photoURL ?? '';
      await UserService.instance.upsertUserProfile(
        uid: user.uid,
        data: {
          'uid': user.uid,
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'dob': _selectedDob!.toIso8601String(),
          'age': age,
          'photos': googlePhoto.isNotEmpty ? [googlePhoto] : [],
          'registrationCompleted': false,
          'createdAt': DateTime.now(),
          'updatedAt': DateTime.now(),
        },
      );
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingFlow()),
          (route) => false,
        );
      }
    } else {
      // Underage or Cancelled -> Delete newly created Firebase user and block access
      await user.delete();
      await AuthService.instance.signOut();
    }
  }

  // ─── Apple Sign-In (placeholder — same pattern as Google) ───
  Future<void> _handleAppleSignIn() async {
    // TODO: Implement Apple Sign-In when ready
    _showError('Apple Sign-In coming soon.');
  }

  // ─── Forgot Password ───
  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Please enter your email first.');
      return;
    }
    try {
      await AuthService.instance.sendPasswordReset(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(AuthService.instance.readableAuthError(e));
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Logo
              Image.asset(
                'assets/images/appicon.png',
                height: 80,
                width: 80,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 8),
              // App Name
              Text(
                "SWAN MATCH",
                style: GoogleFonts.cinzel(
                  color: AppColors.goldMedium,
                  fontSize: 28,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                "Welcome back",
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              // Subtitle
              const Text(
                "Login to your account",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),

              // Email Field
              _buildTextField(
                controller: _emailController,
                hintText: "Email",
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),

              // Password Field
              _buildTextField(
                controller: _passwordController,
                hintText: "Password",
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white54,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),

              const SizedBox(height: 8),
              // Forgot Password
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordPage(),
                      ),
                    );
                  },
                  child: Text(
                    "Forgot password?",
                    style: TextStyle(
                      color: AppColors.goldMedium,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              // Login Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleEmailLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.goldMedium,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Login",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),
              // Or continue with
              Row(
                children: [
                  const Expanded(
                    child: Divider(color: Colors.white24, thickness: 1),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "or continue with",
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                  const Expanded(
                    child: Divider(color: Colors.white24, thickness: 1),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              // Google Button
              _buildSocialButton(
                icon: FontAwesomeIcons.google,
                iconColor: Colors.white,
                text: "Continue with Google",
                isLoading: _isGoogleLoading,
                onPressed: _isGoogleLoading ? () {} : _handleGoogleSignIn,
              ),
              const SizedBox(height: 12),
              // Apple Button
              _buildSocialButton(
                icon: FontAwesomeIcons.apple,
                iconColor: Colors.white,
                text: "Continue with Apple",
                isLoading: _isAppleLoading,
                onPressed: _isAppleLoading ? () {} : _handleAppleSignIn,
              ),

              const SizedBox(height: 20),
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (ctx, anim, sec) =>
                              const CustomSignupPage(),
                          transitionsBuilder: (ctx, animation, sec, child) =>
                              FadeTransition(opacity: animation, child: child),
                        ),
                      );
                    },
                    child: Text(
                      "Sign up",
                      style: TextStyle(
                        color: AppColors.goldMedium,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String hintText,
    TextEditingController? controller,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.white54, fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required FaIconData icon,
    required Color iconColor,
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white24, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(icon, color: iconColor, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
