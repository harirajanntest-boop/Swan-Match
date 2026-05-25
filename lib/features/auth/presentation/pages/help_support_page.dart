import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/user_service.dart';
import '../../../../services/support_service.dart';
import '../../../../services/security_monitoring_service.dart';

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  
  String _selectedSubject = 'General Inquiry';
  bool _isSubmitting = false;

  final List<String> _subjects = [
    'General Inquiry',
    'Billing & Subscription',
    'Profile & Verification',
    'Report Abuse / Safety',
    'Technical Bug / Glitch',
    'Feedback & Suggestion',
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitForm(String userName, String userEmail) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 1. Gather device metadata
      final deviceData = await SecurityMonitoringService.instance.getDeviceInfo();
      final deviceInfo = {
        'osVersion': deviceData['osVersion'] ?? 'Unknown OS',
        'deviceModel': deviceData['model'] ?? 'Unknown Model',
        'deviceBrand': deviceData['brand'] ?? 'Unknown Brand',
        'appVersion': '1.0.0', // Standard app fallback version
      };

      // 2. Submit to Firestore.
      // This triggers the `onSupportQueryCreated` Cloud Function which
      // automatically sends a professional HTML email to support@swan-match.com
      // with full ticket details, priority level, and SLA deadline.
      // No manual email action is needed from the user.
      await SupportService.instance.submitSupportQuery(
        userName: userName,
        userEmail: userEmail,
        subject: _selectedSubject,
        message: _messageController.text.trim(),
        deviceInfo: deviceInfo,
      );

      // 3. Show success dialog
      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.errorRed,
            content: Text(
              'Failed to submit support query: ${e.toString()}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }


  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.goldMedium, width: 1.5),
          ),
          backgroundColor: AppColors.onyx,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.goldMedium.withOpacity(0.1),
                    border: Border.all(color: AppColors.goldMedium, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.goldMedium,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'TICKET CREATED',
                  style: TextStyle(
                    color: AppColors.goldMedium,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your query has been submitted successfully. A moderator will review your request and get back to you shortly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Pop Dialog
                      Navigator.pop(context); // Pop HelpSupportPage back to Settings
                    },
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: const Text(
                          'RETURN TO SETTINGS',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.goldMedium, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'HELP & SUPPORT',
          style: TextStyle(
            color: AppColors.goldMedium,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: UserService.instance.watchCurrentUserProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.goldMedium),
            );
          }

          final profile = snapshot.data ?? <String, dynamic>{};
          final String userName = (profile['name'] ?? 'User').toString();
          final String userEmail = (profile['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '').toString();

          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How can we help you?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please fill out the form below. Our support team typically responds within 24 hours.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // LOCKED PROFILE NAME
                    _buildLabel('YOUR NAME'),
                    _buildLockedField(userName, Icons.person_outline),
                    const SizedBox(height: 20),

                    // LOCKED PROFILE EMAIL
                    _buildLabel('YOUR EMAIL'),
                    _buildLockedField(userEmail, Icons.mail_outline),
                    const SizedBox(height: 20),

                    // SUBJECT SELECTOR
                    _buildLabel('SUBJECT'),
                    _buildSubjectDropdown(),
                    const SizedBox(height: 20),

                    // MESSAGE INPUT
                    _buildLabel('MESSAGE'),
                    _buildMessageField(),
                    const SizedBox(height: 32),

                    // SUBMIT BUTTON
                    _buildSubmitButton(userName, userEmail),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.goldMedium,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildLockedField(String value, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.onyx.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.onyx, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Icon(Icons.lock_outline, color: AppColors.textSubtle, size: 16),
        ],
      ),
    );
  }

  Widget _buildSubjectDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.onyx,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.onyx, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSubject,
          dropdownColor: AppColors.onyx,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.goldMedium),
          isExpanded: true,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedSubject = newValue;
              });
            }
          },
          items: _subjects.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMessageField() {
    return TextFormField(
      controller: _messageController,
      maxLines: 6,
      maxLength: 1000,
      keyboardType: TextInputType.multiline,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        height: 1.4,
      ),
      cursorColor: AppColors.goldMedium,
      decoration: InputDecoration(
        hintText: 'Describe your inquiry or issue in detail...',
        hintStyle: const TextStyle(color: AppColors.textSubtle, fontSize: 14),
        fillColor: AppColors.onyx,
        filled: true,
        counterStyle: const TextStyle(color: AppColors.textMuted),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.goldMedium, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.onyx, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.errorRed, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.errorRed, width: 1.5),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your message';
        }
        if (value.trim().length < 10) {
          return 'Message must be at least 10 characters long';
        }
        return null;
      },
    );
  }

  Widget _buildSubmitButton(String userName, String userEmail) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.zero,
        ),
        onPressed: _isSubmitting ? null : () => _submitForm(userName, userEmail),
        child: Ink(
          decoration: BoxDecoration(
            gradient: _isSubmitting ? null : AppColors.goldGradient,
            color: _isSubmitting ? AppColors.onyx : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            alignment: Alignment.center,
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: AppColors.goldMedium,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    'SUBMIT SUPPORT QUERY',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
