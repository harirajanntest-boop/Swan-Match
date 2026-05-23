import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swam_match_app/core/constants/colors.dart';
import 'package:swam_match_app/services/auth_service.dart';
import 'package:swam_match_app/services/user_service.dart';
import 'package:swam_match_app/shared/widgets/gold_button.dart';
import 'custom_login_page.dart';
import 'verify_email_page.dart';
import 'onboarding_flow.dart';
import 'main_dashboard.dart';
import 'intro_onboarding_screens.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    // Navigate after a 2.5-second delay
    Timer(const Duration(milliseconds: 2500), _checkAuth);
  }

  Future<void> _checkAuth() async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Check if user has completed registration
      try {
        final profile = await UserService.instance.getUserProfile(user.uid, forceRefresh: true);
        if (!mounted) return;
        if (profile != null &&
            UserService.instance.isAccountSuspended(profile)) {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (ctx, anim, sec) => const CustomLoginPage(),
              transitionsBuilder: (ctx, animation, sec, child) =>
                  FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 800),
            ),
          );
          return;
        }

        if (profile != null && profile['registrationCompleted'] == true) {
          // Email verification gate: skip for OAuth providers
          final providers = List<String>.from(profile['providers'] ?? []);
          final hasOAuth = providers.any((p) => p == 'google.com' || p == 'apple.com');
          if (!hasOAuth) {
            final emailVerified = await AuthService.instance.checkEmailVerified();
            if (!emailVerified) {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (ctx, anim, sec) => const VerifyEmailPage(),
                transitionsBuilder: (ctx, animation, sec, child) => FadeTransition(opacity: animation, child: child),
                transitionDuration: const Duration(milliseconds: 800),
              ),
            );
            return;
          }
          }
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (ctx, anim, sec) => const MainDashboard(),
              transitionsBuilder: (ctx, animation, sec, child) => FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 800),
            ),
          );
        } else {
          // Logged in but incomplete profile → details filling
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (ctx, anim, sec) => const OnboardingFlow(),
              transitionsBuilder: (ctx, animation, sec, child) => FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 800),
            ),
          );
        }
      } catch (_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (ctx, anim, sec) => const OnboardingFlow(),
            transitionsBuilder: (ctx, animation, sec, child) => FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    } else {
      // Check if user has seen intro onboarding
      final prefs = await SharedPreferences.getInstance();
      final hasSeenIntro = prefs.getBool('hasSeenIntroOnboarding') ?? false;
      
      if (!mounted) return;
      
      if (hasSeenIntro) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (ctx, anim, sec) => const CustomLoginPage(),
            transitionsBuilder: (ctx, animation, sec, child) => FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (ctx, anim, sec) => const IntroOnboardingScreens(),
            transitionsBuilder: (ctx, animation, sec, child) => FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/appicon.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                Text(
                  "SWAN MATCH",
                  style: GoogleFonts.cinzel(
                    color: AppColors.goldMedium,
                    fontSize: 32,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Intentional connection\nfor a lifetime.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
