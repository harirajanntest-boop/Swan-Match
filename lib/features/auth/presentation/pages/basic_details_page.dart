import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/registration_draft_service.dart';
import '../../../../shared/widgets/gold_button.dart';
import 'otp_verification_page.dart';

class BasicDetailsPage extends StatefulWidget {
  const BasicDetailsPage({super.key});

  @override
  State<BasicDetailsPage> createState() => _BasicDetailsPageState();
}

class _BasicDetailsPageState extends State<BasicDetailsPage>
    with SingleTickerProviderStateMixin {
  // ─── Animations ────────────────────────────────────────────────────────────
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ─── Form State ────────────────────────────────────────────────────────────
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _phoneFocus = FocusNode();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _obscurePassword = true;
  String _selectedCountryCode = '+91'; // Defaulting based on context

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

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

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _phoneFocus.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _requestOtpForRegistration() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().length < 8 ||
        _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all required details.')),
      );
      return;
    }

    String formattedPhone;
    try {
      formattedPhone = AuthService.instance.normalizePhoneE164(
        _phoneController.text.trim(),
        defaultCountryCode: _selectedCountryCode,
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.instance.readableAuthError(error))),
      );
      return;
    }

    try {
      RegistrationDraftService.instance.setValues(<String, dynamic>{
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'phoneNumber': formattedPhone,
        'selectedCountryCode': _selectedCountryCode,
      });

      await AuthService.instance.sendOtp(phoneNumber: formattedPhone);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationPage(
            phoneNumber: formattedPhone,
            flowType: OtpFlowType.registration,
            otpDeliveryChannel: OtpDeliveryChannel.sms,
            destination: formattedPhone,
          ),
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.instance.readableAuthError(error))),
      );
    }
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
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Basic Details",
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'serif',
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ─── Progress Bar (Advanced to 30%) ───
          Container(
            height: 2,
            width: double.infinity,
            color: Colors.white.withOpacity(0.05),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.30, // 30% complete
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.goldMedium.withOpacity(0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: AnimatedBuilder(
                animation: _entryController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          Text(
                            "Let's get to know you",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 24,
                              fontFamily: 'serif',
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Please enter your genuine details to find the best matches.",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 40),

                          // ─── Glass Form Container ───
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
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
                                    // Name
                                    _PremiumInputField(
                                      label: "Your Name",
                                      icon: Icons.person_outline,
                                      focusNode: _nameFocus,
                                      keyboardType: TextInputType.name,
                                      controller: _nameController,
                                    ),
                                    const SizedBox(height: 24),

                                    // Email
                                    _PremiumInputField(
                                      label: "Email Address",
                                      icon: Icons.email_outlined,
                                      focusNode: _emailFocus,
                                      keyboardType: TextInputType.emailAddress,
                                      controller: _emailController,
                                    ),
                                    const SizedBox(height: 24),

                                    // Password
                                    _PremiumInputField(
                                      label: "Create Password",
                                      icon: Icons.lock_outline,
                                      focusNode: _passwordFocus,
                                      obscureText: _obscurePassword,
                                      isPassword: true,
                                      controller: _passwordController,
                                      helperText:
                                          "Your password must be within 8-20 characters",
                                      onTogglePassword: () {
                                        setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 32),

                                    // Phone Number (Custom layout)
                                    _PremiumPhoneField(
                                      focusNode: _phoneFocus,
                                      countryCode: _selectedCountryCode,
                                      controller: _phoneController,
                                      onCountryCodeTapped: () {
                                        // Open a bottom sheet to select country code later
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // ─── Action Button ───
                          GoldGradientButton(
                            text: "GET OTP",
                            onPressed: _requestOtpForRegistration,
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Special Premium Phone Input Field ───────────────────────────────────────
class _PremiumPhoneField extends StatefulWidget {
  final FocusNode focusNode;
  final String countryCode;
  final TextEditingController controller;
  final VoidCallback onCountryCodeTapped;

  const _PremiumPhoneField({
    required this.focusNode,
    required this.countryCode,
    required this.controller,
    required this.onCountryCodeTapped,
  });

  @override
  State<_PremiumPhoneField> createState() => _PremiumPhoneFieldState();
}

class _PremiumPhoneFieldState extends State<_PremiumPhoneField> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      setState(() {
        _isFocused = widget.focusNode.hasFocus;
      });
    });
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
          child: const Text("Phone Number"),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Country Code Selector
            GestureDetector(
              onTap: widget.onCountryCodeTapped,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.public,
                      color: AppColors.goldMedium,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.countryCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white.withOpacity(0.5),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Actual Number Input
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                keyboardType: TextInputType.phone,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
                cursorColor: AppColors.goldMedium,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),

        // Animated Liquid Gold Bottom Border
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
        const SizedBox(height: 6),
        Text(
          "OTP will be sent to this number",
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

// ─── Standard Premium Input Field (Updated for Helper Text) ──────────────────
class _PremiumInputField extends StatefulWidget {
  final String label;
  final IconData icon;
  final FocusNode focusNode;
  final TextEditingController controller;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onTogglePassword;
  final TextInputType keyboardType;
  final String? helperText; // Added helper text capability

  const _PremiumInputField({
    required this.label,
    required this.icon,
    required this.focusNode,
    required this.controller,
    this.isPassword = false,
    this.obscureText = false,
    this.onTogglePassword,
    this.keyboardType = TextInputType.text,
    this.helperText,
  });

  @override
  State<_PremiumInputField> createState() => _PremiumInputFieldState();
}

class _PremiumInputFieldState extends State<_PremiumInputField> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      setState(() {
        _isFocused = widget.focusNode.hasFocus;
      });
    });
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
        // Helper Text (e.g. for password requirements)
        if (widget.helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.helperText!,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}
