import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/gestures.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:swam_match_app/core/constants/colors.dart';
import 'package:swam_match_app/services/auth_service.dart';
import 'package:swam_match_app/services/user_service.dart';
import 'package:swam_match_app/features/auth/presentation/pages/custom_signup_page.dart';
import 'package:swam_match_app/features/auth/presentation/pages/onboarding_flow.dart';
import 'package:swam_match_app/features/auth/presentation/pages/main_dashboard.dart';
import 'package:swam_match_app/features/auth/presentation/pages/verify_email_page.dart';
import 'package:swam_match_app/shared/helpers/account_suspension_helper.dart';
import 'package:swam_match_app/shared/helpers/age_helper.dart';
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
  Future<void> _routeUser(User user, {Map<String, dynamic>? profile}) async {
    if (!mounted) return;
    try {
      // Reuse a profile the caller already fetched; only hit Firestore if absent.
      final userProfile =
          profile ?? await UserService.instance.getUserProfile(user.uid, forceRefresh: true);
      if (!mounted) return;

      if (userProfile != null &&
          UserService.instance.isAccountSuspended(userProfile)) {
        if (!mounted) return;
        await AccountSuspensionHelper.blockIfSuspended(context);
        return;
      }

      final hasOAuth = user.providerData.any(
        (p) => p.providerId == 'google.com' || p.providerId == 'apple.com',
      );
      if (!hasOAuth) {
        final emailVerified = await AuthService.instance.checkEmailVerified();
        if (!emailVerified) {
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const VerifyEmailPage()),
            (route) => false,
          );
          return;
        }
      }

      if (userProfile != null && userProfile['registrationCompleted'] == true) {
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
      print('DEBUG _routeUser error: $e');
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

    bool throttlePassed = false;
    try {
      // Login throttling check before attempting sign-in
      await AuthService.instance.checkLoginThrottle(email);
      throttlePassed = true;

      final credential = await AuthService.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        _showError('Login failed. Please try again.');
        return;
      }
      // Report successful login to clear throttle counter — fire-and-forget so
      // it doesn't block routing into the app.
      AuthService.instance.reportLoginSuccess(email).catchError((_) {});

      // Check if terms already accepted
      final profile = await UserService.instance.getUserProfile(user.uid, forceRefresh: true);
      if (profile == null || profile['termsAccepted'] != true) {
        if (!mounted) return;
        final accepted = await _showTermsDialog();
        if (accepted != true) {
          await AuthService.instance.signOut();
          return;
        }
        await UserService.instance.updateCurrentUserProfile({
          'termsAccepted': true,
          'termsAcceptedAt': DateTime.now(),
        });
      }

      // Reuse the profile fetched above instead of letting _routeUser refetch.
      await _routeUser(user, profile: profile);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // Report failed login attempt only if we successfully cleared the throttle check
      // and this itself isn't a pre-existing rate limit error.
      if (throttlePassed && e.code != 'too-many-requests') {
        await AuthService.instance.reportLoginFailure(email);
      }
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
      if (throttlePassed) {
        await AuthService.instance.reportLoginFailure(email);
      }
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

      final profile = await UserService.instance.getUserProfile(user.uid, forceRefresh: true);

      if (profile != null) {
        // Existing User -> terms already accepted, just route (reuse profile).
        await _routeUser(user, profile: profile);
      } else {
        // New Google User -> ask terms first, then DOB
        if (!mounted) return;
        final termsAccepted = await _showTermsDialog();
        if (termsAccepted != true) {
          await user.delete();
          await AuthService.instance.signOut();
          return;
        }
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

  Future<bool?> _showTermsDialog() async {
    bool termsAccepted = false;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.onyx,
              title: const Text(
                "Terms & Privacy",
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Please accept our Terms of Service and Privacy Policy to continue.",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: termsAccepted,
                        activeColor: AppColors.goldMedium,
                        onChanged: (v) {
                          setDialogState(() => termsAccepted = v ?? false);
                        },
                      ),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                            children: [
                              const TextSpan(text: "I accept the "),
                              TextSpan(
                                text: "Terms of Service",
                                style: const TextStyle(
                                  color: AppColors.goldMedium,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _launchUrl("https://www.swan-match.com/terms"),
                              ),
                              const TextSpan(text: " and "),
                              TextSpan(
                                text: "Privacy Policy",
                                style: const TextStyle(
                                  color: AppColors.goldMedium,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _launchUrl("https://www.swan-match.com/privacy"),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: termsAccepted
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: const Text("Continue", style: TextStyle(color: AppColors.goldMedium)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showGoogleDobDialog(User user) async {
    DateTime? tempDob = defaultAdultDob();
    
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
      final existing = await UserService.instance.getUserProfile(
        user.uid,
        forceRefresh: true,
      );
      final data = <String, dynamic>{
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'dob': _selectedDob!.toIso8601String(),
        'age': age,
        'photos': googlePhoto.isNotEmpty ? [googlePhoto] : [],
        'termsAccepted': false,
        'termsAcceptedAt': null,
        'registrationCompleted': false,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      };

      if (existing == null) {
        data.addAll({
          'isVerified': false,
          'idVerified': false,
          'profileVerified': false,
          'profileApprovalStatus': 'pending',
          'verificationStatus': 'pending',
          'subscriptionPlan': 'free',
          'subscriptionName': 'Free',
          'account': 'active',
        });
      }

      try {
        await UserService.instance.upsertUserProfile(uid: user.uid, data: data);
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          _showError(
            'Account created, but profile write was blocked by Firestore rules. '
            'Please retry after a moment or contact support if this persists.',
          );
        }
        rethrow;
      }
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

  // ─── Apple Sign-In ───
  Future<void> _handleAppleSignIn() async {
    if (_isAppleLoading) return;
    setState(() => _isAppleLoading = true);

    try {
      // Clear any stale anonymous/partial session so we authenticate fresh
      // (avoids failed "link" attempts that surface as login errors on iPad).
      if (FirebaseAuth.instance.currentUser != null) {
        try {
          await AuthService.instance.signOut();
        } catch (_) {}
      }

      final userCredential = await AuthService.instance.signInWithApple();
      if (userCredential == null) {
        setState(() => _isAppleLoading = false);
        return;
      }

      final user = userCredential.user;
      if (user == null) {
        _showError('Failed to get user from Apple.');
        return;
      }

      final profile = await UserService.instance.getUserProfile(user.uid, forceRefresh: true);

      if (profile != null) {
        // Existing user -> route (reuse profile).
        await _routeUser(user, profile: profile);
      } else {
        // New Apple user -> terms first, then DOB (Apple doesn't provide age).
        if (!mounted) return;
        final termsAccepted = await _showTermsDialog();
        if (termsAccepted != true) {
          await user.delete();
          await AuthService.instance.signOut();
          return;
        }
        if (!mounted) return;
        await _showGoogleDobDialog(user);
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return;
      if (!mounted) return;
      // "unknown" (error 1000) is almost always a device/Apple ID setup issue.
      _showError(e.code == AuthorizationErrorCode.unknown
          ? 'Apple Sign-In couldn\'t start. Make sure you\'re signed in to your Apple ID in Settings with two-factor authentication on, then try again — or use email login.'
          : 'Apple Sign-In could not be completed (${e.code.name}). Please try again or use email login.');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      debugPrint('APPLE_SIGNIN_FB_ERROR code=${e.code} msg=${e.message}');
      if (e.code == 'account-exists-with-different-credential') {
        _showError(AuthService.instance.readableAuthError(e));
        return;
      }
      final isAppleConfig = e.code == 'invalid-credential' ||
          e.code == 'operation-not-allowed';
      _showError(isAppleConfig
          ? 'Apple Sign-In isn\'t available right now (${e.code}). Please try another method.'
          : AuthService.instance.readableAuthError(e));
    } catch (e) {
      if (!mounted) return;
      debugPrint('APPLE_SIGNIN_UNKNOWN_ERROR: $e');
      _showError(
        'Apple Sign-In failed. Please try again or use email / Google login.',
      );
    } finally {
      if (mounted) setState(() => _isAppleLoading = false);
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        _showError('Could not launch link.');
      }
    } catch (_) {
      if (mounted) _showError('Could not launch link.');
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
                maxLength: 254,
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
              // Apple Button — iOS only (Sign in with Apple isn't available on
              // Android, and the handler is still a stub there).
              if (Platform.isIOS) ...[
                const SizedBox(height: 12),
                _buildSocialButton(
                  icon: FontAwesomeIcons.apple,
                  iconColor: Colors.white,
                  text: "Continue with Apple",
                  isLoading: _isAppleLoading,
                  onPressed: _isAppleLoading ? () {} : _handleAppleSignIn,
                ),
              ],

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
    int? maxLength,
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
        maxLength: maxLength,
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
          counterText: '',
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
