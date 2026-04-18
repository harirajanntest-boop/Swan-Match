import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/widgets/gold_button.dart';
import 'house_rules_screen.dart';
import 'main_dashboard.dart';
import 'phone_input_page.dart';
import 'simple_onboarding.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool _isGoogleLoading = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isGoogleLoading) return;
    
    setState(() => _isGoogleLoading = true);
    
    try {
      print('DEBUG: Starting Google sign-in...');
      final userCredential = await AuthService.instance.signInWithGoogle();
      print('DEBUG: Google sign-in result: $userCredential');
      print('DEBUG: About to enter normal flow...');
      
      if (userCredential == null) {
        print('DEBUG: Google sign-in cancelled by user');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google sign-in cancelled')),
          );
        }
        return;
      }

      final user = userCredential.user!;
      print('DEBUG: Google user authenticated: ${user.uid}, email: ${user.email}');
      
      // Check if user exists in database first
      print('DEBUG: Checking if user exists in database...');
      final userDoc = await UserService.instance.getUserProfile(user.uid);
      print('DEBUG: User document from database: $userDoc');
      
      if (userDoc == null) {
        // New user - create account and go to House Rules
        print('DEBUG: New user detected, creating account...');
        final googlePhoto = user.photoURL ?? '';
        await UserService.instance.upsertUserProfile(
          uid: user.uid,
          data: {
            'name': user.displayName ?? '',
            'email': user.email ?? '',
            'phoneNumber': user.phoneNumber ?? '',
            'photos': googlePhoto.isNotEmpty ? [googlePhoto] : [],
            'registrationCompleted': false, // Will be updated to true after onboarding
          },
        );
        print('DEBUG: User account created successfully');
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HouseRulesScreen()),
          );
        }
      } else {
        // Existing user - check if registration completed
        print('DEBUG: Existing user found, checking registration status...');
        if (userDoc['registrationCompleted'] == true) {
          print('DEBUG: User already completed onboarding, going to dashboard');
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainDashboard()),
            );
          }
        } else {
          print('DEBUG: Existing user needs onboarding, going to House Rules');
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HouseRulesScreen()),
            );
          }
        }
      }
    } on GoogleNoAccountException catch (e) {
      print('DEBUG: GoogleNoAccountException caught: ${e.toString()}');
      // Handle new Google user - create account and proceed to House Rules
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('DEBUG: Creating user account from GoogleNoAccountException handler');
        final googlePhoto = user.photoURL ?? '';
        await UserService.instance.upsertUserProfile(
          uid: user.uid,
          data: {
            'name': user.displayName ?? '',
            'email': user.email ?? '',
            'phoneNumber': user.phoneNumber ?? '',
            'photos': googlePhoto.isNotEmpty ? [googlePhoto] : [],
            'registrationCompleted': false,
          },
        );
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HouseRulesScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = 'Authentication failed';
        
        // Handle specific Firebase Auth errors
        switch (e.code) {
          case 'account-exists-with-different-credential':
            errorMessage = 'An account already exists with this email';
            break;
          case 'invalid-credential':
            errorMessage = 'Invalid Google credentials';
            break;
          case 'user-disabled':
            errorMessage = 'This account has been disabled';
            break;
          case 'user-not-found':
            errorMessage = 'No account found for this email';
            break;
          case 'network-request-failed':
            errorMessage = 'Network error. Please check your connection';
            break;
          case 'too-many-requests':
            errorMessage = 'Too many requests. Try again later';
            break;
          default:
            errorMessage = e.message ?? 'An error occurred during sign-in';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  void _handlePhoneSignIn() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PhoneInputPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 80),

                  // App Logo Image
                  Image.asset(
                    'assets/images/image.png',
                    width: 120,
                    height: 120,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.goldMedium,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.favorite_border,
                            size: 60,
                            color: AppColors.goldMedium,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                  
                  // App Name and Tagline
                  Text(
                    'SWAN MATCH',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.goldMedium,
                      letterSpacing: 2,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    'Where hearts find their home',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.goldLight,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Legal Text
                  Text(
                    'By continuing, you agree to our Terms of Service, Privacy Policy, and Cookie Policy.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Google Sign In Button
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: _isGoogleLoading ? null : _handleGoogleSignIn,
                        child: Center(
                          child: _isGoogleLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.obsidian,
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'assets/images/google_logo.png',
                                      width: 24,
                                      height: 24,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Icon(
                                          Icons.account_circle,
                                          size: 24,
                                          color: Colors.grey[700],
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Continue with Google',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.obsidian,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Phone Sign In Button
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: _handlePhoneSignIn,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.phone,
                                size: 24,
                                color: AppColors.obsidian,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Continue with Phone Number',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.obsidian,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Trouble Signing In
                  TextButton(
                    onPressed: () {
                      // TODO: Implement help/trouble signing in
                    },
                    child: Text(
                      'Trouble signing in?',
                      style: TextStyle(
                        color: AppColors.goldLight,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
