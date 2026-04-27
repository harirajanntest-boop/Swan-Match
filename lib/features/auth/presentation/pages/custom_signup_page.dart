import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swam_match_app/core/constants/colors.dart';
import 'package:swam_match_app/services/auth_service.dart';
import 'package:swam_match_app/services/user_service.dart';
import 'package:swam_match_app/features/auth/presentation/pages/custom_login_page.dart';
import 'package:swam_match_app/features/auth/presentation/pages/onboarding_flow.dart';
import 'package:swam_match_app/features/auth/presentation/pages/main_dashboard.dart';

class CustomSignupPage extends StatefulWidget {
  const CustomSignupPage({super.key});

  @override
  State<CustomSignupPage> createState() => _CustomSignupPageState();
}

class _CustomSignupPageState extends State<CustomSignupPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
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
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingFlow()),
        (route) => false,
      );
    }
  }

  // ─── Email / Password Sign Up ───
  Future<void> _handleEmailSignup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }

    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create the account in Firebase Auth
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = credential.user;
      if (user == null) {
        _showError('Account creation failed. Please try again.');
        return;
      }

      // Save name and initial profile to Firestore
      await UserService.instance.upsertUserProfile(
        uid: user.uid,
        data: {
          'uid': user.uid,
          'name': name,
          'email': email,
          'registrationCompleted': false,
          'createdAt': DateTime.now(),
          'updatedAt': DateTime.now(),
        },
      );

      if (!mounted) return;

      // Navigate to details filling screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingFlow()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'email-already-in-use') {
        _showError(
          'An account already exists with this email. Please login instead.',
        );
      } else {
        _showError(AuthService.instance.readableAuthError(e));
      }
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
      // Step 1: Open Google account picker & store credential temporarily
      final directResult = await AuthService.instance.signInWithGoogle();

      if (directResult != null) {
        // Existing user was already signed in (linked account case)
        final user = directResult.user;
        if (user != null) {
          await _routeUser(user);
          return;
        }
      }

      // Step 2: Check if temporary credential was stored
      if (!AuthService.instance.hasPendingCredentials) {
        // User cancelled the picker
        return;
      }

      // Step 3: Complete Firebase sign-in
      final userCredential = await AuthService.instance.completeDelayedSignIn();
      final user = userCredential.user;
      if (user == null) {
        _showError('Failed to sign in with Google.');
        return;
      }

      // Step 4: Check if user profile exists in Firestore
      final profile = await UserService.instance.getUserProfile(user.uid);

      if (profile == null) {
        // New user — create initial profile with Google info
        final googlePhoto = user.photoURL ?? '';
        await UserService.instance.upsertUserProfile(
          uid: user.uid,
          data: {
            'uid': user.uid,
            'name': user.displayName ?? '',
            'email': user.email ?? '',
            'phoneNumber': user.phoneNumber ?? '',
            'photos': googlePhoto.isNotEmpty ? [googlePhoto] : [],
            'registrationCompleted': false,
            'createdAt': DateTime.now(),
            'updatedAt': DateTime.now(),
          },
        );

        if (!mounted) return;
        // Navigate to details filling screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingFlow()),
          (route) => false,
        );
      } else {
        // Existing user — route based on registration status
        await _routeUser(user);
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

  // ─── Apple Sign-In (placeholder) ───
  Future<void> _handleAppleSignIn() async {
    _showError('Apple Sign-In coming soon.');
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
                "Create your account",
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              // Subtitle
              const Text(
                "Let's get to know you",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),

              // Full Name Field
              _buildTextField(
                controller: _nameController,
                hintText: "Full Name",
                keyboardType: TextInputType.name,
              ),
              const SizedBox(height: 10),

              // Email Field
              _buildTextField(
                controller: _emailController,
                hintText: "Email",
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),

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

              const SizedBox(height: 20),
              // Sign Up Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleEmailSignup,
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
                          "Sign Up",
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
                    "Already have an account? ",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (ctx, anim, sec) =>
                              const CustomLoginPage(),
                          transitionsBuilder: (ctx, animation, sec, child) =>
                              FadeTransition(opacity: animation, child: child),
                        ),
                      );
                    },
                    child: Text(
                      "Login",
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
