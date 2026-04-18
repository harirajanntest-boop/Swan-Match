import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/user_service.dart';
import 'main_dashboard.dart';
import 'simple_onboarding.dart';

class SimpleOtpPage extends StatefulWidget {
  final String phoneNumber;

  const SimpleOtpPage({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<SimpleOtpPage> createState() => _SimpleOtpPageState();
}

class _SimpleOtpPageState extends State<SimpleOtpPage> {
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  bool _isVerifying = false;
  bool _canResend = false;
  int _resendTimer = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    
    // Auto-focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() => _canResend = false);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        timer.cancel();
        setState(() => _canResend = true);
      }
    });
  }

  void _onTextChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _controllers.map((controller) => controller.text).join();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit OTP.')),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final credential = await AuthService.instance.signInWithPhoneOtp(otp);
      
      final user = credential.user!;
      
      // Check if user exists in database
      final userDoc = await UserService.instance.getUserProfile(user.uid);
      
      if (userDoc == null) {
        // New user - create account and go to onboarding
        await UserService.instance.upsertUserProfile(
          uid: user.uid,
          data: {
            'name': '',
            'email': '',
            'phoneNumber': widget.phoneNumber,
            'registrationCompleted': false,
          },
        );
        
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const SimpleOnboarding()),
            (route) => false,
          );
        }
      } else {
        // Existing user - update last login and check registration
        await UserService.instance.updateCurrentUserProfile({
          'lastLoginAt': DateTime.now(),
        });
        
        if (userDoc['registrationCompleted'] == true) {
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MainDashboard()),
              (route) => false,
            );
          }
        } else {
          // User exists but didn't complete onboarding
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const SimpleOnboarding()),
              (route) => false,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;
    
    try {
      await AuthService.instance.sendOtp(phoneNumber: widget.phoneNumber);
      _startResendTimer();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP sent successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
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
          icon: Icon(Icons.arrow_back, color: AppColors.goldMedium),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              
              Text(
                'Verification',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.goldMedium,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Enter the 6-digit code sent to',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              
              const SizedBox(height: 4),
              
              Text(
                widget.phoneNumber,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.goldMedium,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // OTP Input Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return Container(
                    width: 50,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _focusNodes[index].hasFocus
                            ? AppColors.goldMedium
                            : AppColors.goldMedium.withOpacity(0.3),
                        width: _focusNodes[index].hasFocus ? 2 : 1,
                      ),
                    ),
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(1),
                      ],
                      onChanged: (value) => _onTextChanged(index, value),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                  );
                }),
              ),
              
              const SizedBox(height: 40),
              
              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.goldMedium,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: _isVerifying
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
                      : Text(
                          'Verify',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.obsidian,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Resend OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Didn\'t receive the code?',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _canResend ? _resendOtp : null,
                    child: Text(
                      _canResend ? 'Resend' : 'Resend ($_resendTimer)',
                      style: TextStyle(
                        color: _canResend ? AppColors.goldMedium : Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
