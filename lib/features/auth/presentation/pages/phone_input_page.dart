import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/user_service.dart';
import 'simple_otp_page.dart';

class PhoneInputPage extends StatefulWidget {
  const PhoneInputPage({super.key});

  @override
  State<PhoneInputPage> createState() => _PhoneInputPageState();
}

class _PhoneInputPageState extends State<PhoneInputPage> {
  final _phoneController = TextEditingController();
  final _phoneFocus = FocusNode();
  String _selectedCountryCode = '+1';
  bool _isSendingOtp = false;

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

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter phone number')),
      );
      return;
    }

    setState(() => _isSendingOtp = true);

    try {
      final phoneNumber = '$_selectedCountryCode${_phoneController.text.trim()}';
      
      await AuthService.instance.sendOtp(phoneNumber: phoneNumber);
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SimpleOtpPage(
              phoneNumber: phoneNumber,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingOtp = false);
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              Text(
                'Enter your phone number',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.goldMedium,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'We\'ll send you a verification code',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Country Code and Phone Number Input
              Row(
                children: [
                  // Country Code Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.goldMedium.withOpacity(0.3),
                      ),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedCountryCode,
                      dropdownColor: AppColors.obsidian,
                      style: TextStyle(
                        color: AppColors.goldMedium,
                        fontSize: 16,
                      ),
                      items: _countryCodes.map((code) {
                        return DropdownMenuItem<String>(
                          value: code,
                          child: Text(code),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedCountryCode = value);
                        }
                      },
                      underline: Container(),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: AppColors.goldMedium,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Phone Number Input
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      focusNode: _phoneFocus,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Phone number',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.goldMedium.withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.goldMedium.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.goldMedium,
                            width: 2,
                          ),
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(15),
                      ],
                    ),
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Send OTP Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSendingOtp ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.goldMedium,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: _isSendingOtp
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
                          'Send OTP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.obsidian,
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
