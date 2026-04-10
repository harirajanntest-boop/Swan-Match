import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/registration_draft_service.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/widgets/gold_button.dart';
import 'main_dashboard.dart';
import 'personal_details_page.dart';

enum OtpFlowType { registration, login }
enum OtpDeliveryChannel { sms, email }

class OtpVerificationPage extends StatefulWidget {
  final String phoneNumber;
  final OtpFlowType flowType;
  final OtpDeliveryChannel otpDeliveryChannel;
  final String destination;
  final String? loginEmail;
  final String? loginPassword;
  final String? loginPhoneNumber;

  const OtpVerificationPage({
    super.key,
    required this.phoneNumber,
    required this.flowType,
    this.otpDeliveryChannel = OtpDeliveryChannel.sms,
    String? destination,
    this.loginEmail,
    this.loginPassword,
    this.loginPhoneNumber,
  }) : destination = destination ?? phoneNumber;

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage>
    with TickerProviderStateMixin {
  // ─── Animations ────────────────────────────────────────────────────────────
  late final AnimationController _bgController;
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ─── OTP Form State ────────────────────────────────────────────────────────
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );

  bool _isSubmitting = false;

  // Timer State
  Timer? _timer;
  int _secondsRemaining = 30;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();

    // Background Glow
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // Entry Animation
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

    // Start OTP Countdown
    _startTimer();

    // Listeners for auto-focus shifting
    for (int i = 0; i < 6; i++) {
      _controllers[i].addListener(() {
        if (_controllers[i].text.length == 1 && i < 5) {
          _focusNodes[i + 1].requestFocus();
        }
      });
    }
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 30;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        setState(() => _canResend = true);
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entryController.dispose();
    _timer?.cancel();
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _resendOtp() async {
    try {
      if (widget.otpDeliveryChannel == OtpDeliveryChannel.email) {
        final email = (widget.loginEmail ?? '').trim();
        if (email.isEmpty) {
          throw FirebaseAuthException(
            code: 'invalid-email',
            message: 'Email is required for email link.',
          );
        }
        await AuthService.instance.sendEmailSignInLink(email: email);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new verification link has been sent.')),
        );
      } else {
        await AuthService.instance.sendOtp(phoneNumber: widget.phoneNumber);
      }
      _startTimer();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.instance.readableAuthError(error))),
      );
    }
  }

  Future<void> _submitOtp() async {
    final otp = _controllers.map((controller) => controller.text).join();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit OTP.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (widget.flowType == OtpFlowType.registration) {
        final draft = RegistrationDraftService.instance.draft;
        final draftEmail = (draft['email'] ?? '').toString().trim();
        final draftPassword = (draft['password'] ?? '').toString();

        if (draftEmail.isEmpty || draftPassword.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Registration session expired. Please go back and request OTP again.',
              ),
            ),
          );
          return;
        }

        await AuthService.instance.registerWithEmailAndPhone(
          email: draftEmail,
          password: draftPassword,
          otpCode: otp,
          profileSeed: <String, dynamic>{
            ...draft,
            'registrationCompleted': false,
          },
        );

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const PersonalDetailsPage()),
          (route) => false,
        );
      } else {
        final loginEmail = (widget.loginEmail ?? '').trim();
        final loginPhone = widget.loginPhoneNumber ?? widget.phoneNumber;

        final needsEmail = widget.otpDeliveryChannel == OtpDeliveryChannel.email;
        final needsPhone = widget.otpDeliveryChannel == OtpDeliveryChannel.sms;

        if ((needsEmail && loginEmail.isEmpty) || (needsPhone && loginPhone.isEmpty)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Login session expired. Please go back and request OTP again.',
              ),
            ),
          );
          return;
        }

        if (widget.otpDeliveryChannel == OtpDeliveryChannel.email) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please use the link sent to your email to complete login.',
              ),
            ),
          );
          return;
        } else {
          await AuthService.instance.signInWithPhoneOtp(otp);
        }

        await UserService.instance.updateCurrentUserProfile(<String, dynamic>{
          'lastLoginAt': DateTime.now(),
        });

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainDashboard()),
          (route) => false,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.instance.readableAuthError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
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
          "Verification",
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'serif',
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // ─── Background Ambient Glow ───
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Positioned(
                top: 0,
                left: -100 + (_bgController.value * 20),
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.goldDark.withOpacity(0.06),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.goldMedium.withOpacity(0.05),
                        blurRadius: 80,
                        spreadRadius: 40,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          Column(
            children: [
              // ─── Progress Bar (Advanced to 45%) ───
              Container(
                height: 2,
                width: double.infinity,
                color: Colors.white.withOpacity(0.05),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.45,
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
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: CustomScrollView(
                      slivers: [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 24,
                            ),
                            child: Column(
                              children: [
                                const SizedBox(height: 20),

                                // ─── Premium Glass Icon ───
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.03),
                                    border: Border.all(
                                      color: AppColors.goldMedium.withOpacity(
                                        0.3,
                                      ),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.goldMedium.withOpacity(
                                          0.05,
                                        ),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.message_outlined,
                                    color: AppColors.goldMedium,
                                    size: 48,
                                  ),
                                ),

                                const SizedBox(height: 32),

                                Text(
                                  "Please enter the 6-digit code\nsent to ${widget.destination}",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontFamily: 'serif',
                                    letterSpacing: 1,
                                    height: 1.5,
                                  ),
                                ),

                                const SizedBox(height: 40),

                                // ─── OTP Glass Input Area ───
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: List.generate(
                                    6,
                                    (index) => _buildOtpBox(index, boxWidth: 44),
                                  ),
                                ),

                                const SizedBox(height: 32),

                                // ─── Timer & Resend ───
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Didn't receive the OTP?",
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.5,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        _canResend
                                            ? GestureDetector(
                                                onTap: _resendOtp,
                                                child: const Text(
                                                  "Resend OTP",
                                                  style: TextStyle(
                                                    color: AppColors.goldMedium,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              )
                                            : Text(
                                                "Resend OTP in ${_secondsRemaining}s",
                                                style: TextStyle(
                                                  color: AppColors.goldMedium
                                                      .withOpacity(0.5),
                                                  fontSize: 14,
                                                ),
                                              ),
                                      ],
                                    ),

                                    // Verify with Missed Call (from your screenshot)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "Or use alternative",
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.5,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        GestureDetector(
                                          onTap: () {},
                                          child: const Text(
                                            "Verify with Missed call",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 48),

                                // ─── Submit Button ───
                                GoldGradientButton(
                                  text: _isSubmitting ? "VERIFYING..." : "SUBMIT",
                                  onPressed: () {
                                    if (_isSubmitting) return;
                                    _submitOtp();
                                  },
                                ),

                                const Spacer(),

                                // ─── Customer Service Footer ───
                                Container(
                                  padding: const EdgeInsets.only(top: 24),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: Colors.white.withOpacity(0.1),
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Facing difficulty?",
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                0.5,
                                              ),
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          const Text(
                                            "Call Customer Service",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.phone_in_talk,
                                            color: AppColors.goldMedium,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "+91 8144998877",
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                0.8,
                                              ),
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

  // ─── Individual Premium Glass OTP Box ───
  Widget _buildOtpBox(int index, {required double boxWidth}) {
    return AnimatedBuilder(
      animation: _focusNodes[index],
      builder: (context, child) {
        bool isFocused = _focusNodes[index].hasFocus;
        bool hasText = _controllers[index].text.isNotEmpty;

        return Container(
          width: boxWidth,
          height: 65,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(isFocused ? 0.08 : 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFocused
                  ? AppColors.goldMedium
                  : hasText
                  ? Colors.white.withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
              width: isFocused ? 1.5 : 1.0,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: AppColors.goldMedium.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 1,
              style: const TextStyle(
                color: AppColors.goldLight,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              cursorColor: AppColors.goldMedium,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                counterText: "", // Hides the '0/1' character counter
                border: InputBorder.none,
              ),
              onChanged: (value) {
                // Auto-focus backwards on delete
                if (value.isEmpty && index > 0) {
                  _focusNodes[index - 1].requestFocus();
                }
              },
            ),
          ),
        );
      },
    );
  }
}
