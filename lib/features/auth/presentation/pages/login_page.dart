import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/auth_service.dart';
import '../../../../shared/widgets/gold_button.dart';
import 'main_dashboard.dart';
import 'onboarding_page.dart';
import 'otp_verification_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  // ─── Animations ────────────────────────────────────────────────────────────
  late final AnimationController _bgController;
  late final AnimationController _entryController;
  late final AnimationController _shimmerController;

  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _shimmerAnim;

  // ─── Form State ────────────────────────────────────────────────────────────
  bool _isPhoneLogin = false; // Toggle between Email and Phone
  bool _obscurePassword = true;
  bool _isSendingOtp = false;
  bool _isGoogleLoading = false;
  String _selectedCountryCode = '+1'; // Defaulting to US

  final List<String> _countryCodes = [
    '+1', // USA / Canada
    '+91', // India
    '+44', // UK
    '+61', // Australia
    '+971', // UAE
    '+65', // Singapore
    '+60', // Malaysia
    '+94', // Sri Lanka
  ];

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _phoneFocus = FocusNode();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    _shimmerAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOutSine),
    );

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entryController.dispose();
    _shimmerController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _phoneFocus.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email and password are required.')),
      );
      return;
    }

    setState(() => _isSendingOtp = true); // Using same loading state for simplicity
    try {
      await AuthService.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainDashboard()),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.instance.readableAuthError(error))),
      );
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _startPhoneLoginOtpFlow() async {
    if (_isSendingOtp) return;
    setState(() => _isSendingOtp = true);
    
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _isSendingOtp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number is required.')),
      );
      return;
    }

    String formattedPhone;
    try {
      formattedPhone = AuthService.instance.normalizePhoneE164(
        phone,
        defaultCountryCode: _selectedCountryCode,
      );
    } catch (error) {
      setState(() => _isSendingOtp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.instance.readableAuthError(error))),
      );
      return;
    }

    try {
      await AuthService.instance.sendOtp(phoneNumber: formattedPhone);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationPage(
            flowType: OtpFlowType.login,
            phoneNumber: formattedPhone,
            otpDeliveryChannel: OtpDeliveryChannel.sms,
            destination: formattedPhone,
            loginPhoneNumber: formattedPhone,
          ),
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.instance.readableAuthError(error))),
      );
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email first.')),
      );
      return;
    }

    try {
      await AuthService.instance.sendPasswordReset(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset link sent to your email.')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.instance.readableAuthError(error))),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      final credential = await AuthService.instance.signInWithGoogle();
      if (!mounted) return;
      if (credential != null) {
        // Sign-in successful or linked! Provide feedback and navigate.
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainDashboard()),
          );
        }
      } else {
        // Canceled
        setState(() => _isGoogleLoading = false);
      }
    } catch (error) {
      if (!mounted) return;
      if (error is GoogleNeedsLinkingException) {
        await _showLinkAccountDialog(error.email);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AuthService.instance.readableAuthError(error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  Future<void> _showLinkAccountDialog(String email) async {
    final passwordController = TextEditingController();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.obsidian,
        title: const Text(
          'Link Your Google Account',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'An account with $email already exists.',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your password to link Google to your account.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Your password',
                hintStyle: const TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.amber),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.amber, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FirebaseAuth.instance.signInWithEmailAndPassword(
                  email: email,
                  password: passwordController.text,
                );

                await AuthService.instance.linkPendingGoogleCredential();

                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const MainDashboard()),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Google linked to your account! ✅'),
                    ),
                  );
                }
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Wrong password or error: ${AuthService.instance.readableAuthError(error)}',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Link Account',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: Stack(
        children: [
          // ─── Background Ambient Glow ───
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Positioned(
                top: -150,
                right: -100 + (_bgController.value * 20),
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.goldDark.withOpacity(0.08),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.goldMedium.withOpacity(0.05),
                        blurRadius: 100,
                        spreadRadius: 50,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ─── Main Content ───
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: AnimatedBuilder(
                  animation: _entryController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 20),
                            const Icon(
                              Icons.lock_outline,
                              color: AppColors.goldMedium,
                              size: 40,
                            ),
                            const SizedBox(height: 20),
                            _ShimmerHeader(
                              shimmer: _shimmerAnim,
                              text: "Welcome Back",
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Sign in to continue your journey",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 35),

                            // ─── Glass Form Card ───
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 15,
                                  sigmaY: 15,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(28),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: AppColors.goldMedium.withOpacity(
                                        0.15,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      // ─── Animated Login Type Toggle ───
                                      _PremiumToggle(
                                        isPhone: _isPhoneLogin,
                                        onChanged: (isPhone) {
                                          setState(
                                            () => _isPhoneLogin = isPhone,
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 30),

                                      // ─── Dynamic Form Area ───
                                      AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 400,
                                        ),
                                        switchInCurve: Curves.easeOutCubic,
                                        switchOutCurve: Curves.easeInCubic,
                                        transitionBuilder: (child, animation) {
                                          return FadeTransition(
                                            opacity: animation,
                                            child: SlideTransition(
                                              position: Tween<Offset>(
                                                begin: const Offset(0.05, 0),
                                                end: Offset.zero,
                                              ).animate(animation),
                                              child: child,
                                            ),
                                          );
                                        },
                                        child: _isPhoneLogin
                                            ? _buildPhoneForm()
                                            : _buildEmailForm(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 25),

                            // ─── Social Login Divider ───
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: AppColors.goldMedium.withOpacity(
                                      0.2,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    "or",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: AppColors.goldMedium.withOpacity(
                                      0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 25),

                            // ─── Google Login Button ───
                            _SocialLoginButton(
                              text: "Continue with Google",
                              icon: Icons.g_mobiledata, // Standard flutter icon for Google
                              isLoading: _isGoogleLoading,
                              onPressed: _handleGoogleSignIn,
                            ),

                            const SizedBox(height: 40),

                            // Bottom Register Prompt
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account? ",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 13,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pushReplacementNamed(
                                    context,
                                    '/create-account',
                                  ),
                                  child: const Text(
                                    "Create Profile",
                                    style: TextStyle(
                                      color: AppColors.goldMedium,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // ─── Back Button (on top so it receives taps) ───
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 10, top: 10),
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: AppColors.goldMedium,
                    size: 20,
                  ),
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                      return;
                    }
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const OnboardingPage(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Form Builders ───
  Widget _buildEmailForm() {
    return Column(
      key: const ValueKey('email_form'),
      children: [
        _PremiumInputField(
          label: "Email Address",
          icon: Icons.email_outlined,
          focusNode: _emailFocus,
          keyboardType: TextInputType.emailAddress,
          controller: _emailController,
        ),
        const SizedBox(height: 25),
        _PremiumInputField(
          label: "Password",
          icon: Icons.key_outlined,
          focusNode: _passwordFocus,
          obscureText: _obscurePassword,
          isPassword: true,
          controller: _passwordController,
          onTogglePassword: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
        const SizedBox(height: 15),
        const SizedBox(height: 15),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _handleForgotPassword,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.goldMedium,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
            ),
            child: const Text(
              "Forgot Password?",
              style: TextStyle(fontSize: 12, letterSpacing: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 30),
        GoldGradientButton(
          text: "LOGIN",
          onPressed: _handleEmailLogin,
          isLoading: _isSendingOtp,
        ),
      ],
    );
  }

  Widget _buildPhoneForm() {
    return Column(
      key: const ValueKey('phone_form'),
      children: [
        _PremiumInputField(
          label: "Phone Number",
          icon: Icons.phone_outlined,
          focusNode: _phoneFocus,
          keyboardType: TextInputType.phone,
          prefixText: "$_selectedCountryCode ",
          onPrefixTapped: _showCountryCodePicker,
          controller: _phoneController,
        ),
        const SizedBox(height: 15),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "An OTP will be sent to your mobile number via SMS.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(height: 30),
        GoldGradientButton(
          text: "SEND OTP",
          onPressed: _startPhoneLoginOtpFlow,
          isLoading: _isSendingOtp,
        ),
      ],
    );
  }

  void _showCountryCodePicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.obsidian,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Select Country Code",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontFamily: 'serif',
                ),
              ),
              const SizedBox(height: 15),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _countryCodes.length,
                  itemBuilder: (context, index) {
                    final code = _countryCodes[index];
                    return ListTile(
                      title: Text(
                        code,
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedCountryCode = code;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Animated Custom Toggle ──────────────────────────────────────────────────
class _PremiumToggle extends StatelessWidget {
  final bool isPhone;
  final Function(bool) onChanged;

  const _PremiumToggle({required this.isPhone, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.goldMedium.withOpacity(0.2)),
      ),
      child: Stack(
        children: [
          // Animated Gold Slider
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: isPhone ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.goldDark.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Clickable Text Labels
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(false),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        color: isPhone
                            ? Colors.white.withOpacity(0.5)
                            : Colors.black,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                      child: const Text("EMAIL"),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(true),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        color: isPhone
                            ? Colors.black
                            : Colors.white.withOpacity(0.5),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                      child: const Text("PHONE"),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Social Login Button ─────────────────────────────────────────────────────
class _SocialLoginButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isLoading;

  const _SocialLoginButton({
    required this.text,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(30),
        splashColor: AppColors.goldMedium.withOpacity(0.2),
        child: Container(
          height: 55,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: AppColors.goldMedium.withOpacity(0.4),
              width: 1.2,
            ),
            color: Colors.white.withOpacity(0.02),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: isLoading
                ? [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.goldLight,
                        ),
                      ),
                    ),
                  ]
                : [
                    Icon(icon, color: AppColors.goldLight, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}

// ─── Custom Premium Input Field (Updated with Prefix) ────────────────────────
class _PremiumInputField extends StatefulWidget {
  final String label;
  final IconData icon;
  final FocusNode focusNode;
  final TextEditingController controller;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onTogglePassword;
  final TextInputType keyboardType;
  final String? prefixText;
  final VoidCallback? onPrefixTapped;

  const _PremiumInputField({
    required this.label,
    required this.icon,
    required this.focusNode,
    required this.controller,
    this.isPassword = false,
    this.obscureText = false,
    this.onTogglePassword,
    this.keyboardType = TextInputType.text,
    this.prefixText,
    this.onPrefixTapped,
  });

  @override
  State<_PremiumInputField> createState() => _PremiumInputFieldState();
}

class _PremiumInputFieldState extends State<_PremiumInputField> {
  bool _isFocused = false;
  late final VoidCallback _focusListener;

  @override
  void initState() {
    super.initState();
    _focusListener = () {
      if (!mounted) return;
      setState(() {
        _isFocused = widget.focusNode.hasFocus;
      });
    };
    widget.focusNode.addListener(_focusListener);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_focusListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: _isFocused
                ? AppColors.goldMedium
                : Colors.white.withOpacity(0.5),
            fontSize: _isFocused ? 12 : 14,
            letterSpacing: 1,
            fontFamily: 'serif',
          ),
          child: Text(widget.label),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              widget.icon,
              color: _isFocused
                  ? AppColors.goldMedium
                  : Colors.white.withOpacity(0.3),
              size: 20,
            ),
            const SizedBox(width: 16),
            if (widget.prefixText != null)
              GestureDetector(
                onTap: widget.onPrefixTapped,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    widget.prefixText!,
                    style: const TextStyle(
                      color: AppColors.goldMedium,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                obscureText: widget.obscureText,
                keyboardType: widget.keyboardType,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  letterSpacing: 1.5,
                ),
                cursorColor: AppColors.goldMedium,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  suffixIcon: widget.isPassword
                      ? IconButton(
                          icon: Icon(
                            widget.obscureText
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.white.withOpacity(0.3),
                            size: 18,
                          ),
                          onPressed: widget.onTogglePassword,
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            Container(
              height: 1,
              width: double.infinity,
              color: Colors.white.withOpacity(0.1),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              left: _isFocused ? 0 : MediaQuery.of(context).size.width / 2,
              right: _isFocused ? 0 : MediaQuery.of(context).size.width / 2,
              child: Container(
                height: 1.5,
                decoration: BoxDecoration(
                  color: AppColors.goldMedium,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.goldMedium.withOpacity(0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Shimmer Header Text ─────────────────────────────────────────────────────
class _ShimmerHeader extends StatelessWidget {
  final Animation<double> shimmer;
  final String text;

  const _ShimmerHeader({required this.shimmer, required this.text});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: const [
              AppColors.goldDark,
              AppColors.goldLight,
              Colors.white,
              AppColors.goldMedium,
              AppColors.goldDark,
            ],
            stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            transform: GradientRotation(shimmer.value),
          ).createShader(bounds),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w600,
              letterSpacing: 4,
              fontFamily: 'serif',
            ),
          ),
        );
      },
    );
  }
}
