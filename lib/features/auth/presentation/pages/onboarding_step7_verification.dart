import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../../models/onboarding_data.dart';
import '../../../../shared/widgets/onboarding_widgets.dart';

class OnboardingStep7Verification extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingStep7Verification({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<OnboardingStep7Verification> createState() =>
      _OnboardingStep7VerificationState();
}

class _OnboardingStep7VerificationState
    extends State<OnboardingStep7Verification> {
  File? _selfieFile;
  File? _idFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.data.verificationPhotoUrl.isNotEmpty) {
      _selfieFile = File(widget.data.verificationPhotoUrl);
    }
    if (widget.data.idVerificationUrl.isNotEmpty) {
      _idFile = File(widget.data.idVerificationUrl);
    }
  }

  Future<void> _takeSelfie() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        preferredCameraDevice: CameraDevice.front,
      );
      if (photo != null) setState(() => _selfieFile = File(photo.path));
    } catch (_) {}
  }

  Future<void> _uploadID() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image != null) setState(() => _idFile = File(image.path));
    } catch (_) {}
  }

  void _handleNext() {
    if (_selfieFile == null) {
      _showError('Please take a selfie for face verification');
      return;
    }
    if (_idFile == null) {
      _showError('Please upload a government ID for verification');
      return;
    }

    // Store local file paths; actual upload happens in onboarding completion.
    widget.data.verificationPhotoUrl = _selfieFile!.path;
    widget.data.idVerificationUrl = _idFile!.path;

    // Never auto-verify — admin must approve from the dashboard.
    widget.data.isVerified = false;
    widget.data.idVerified = false; // stays false until admin approves
    widget.data.profileApprovalStatus = 'pending';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '✅ Documents submitted! Your ID will be verified within 24 hours. '
          'Once approved by our team, you will receive the verified badge.',
        ),
        backgroundColor: Colors.green[700],
        duration: const Duration(seconds: 5),
      ),
    );

    widget.onNext();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Verification',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontFamily: 'PlayfairDisplay',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Verify your identity for trust & safety',
            style: TextStyle(color: Colors.white54, fontSize: 15),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Trust Badge Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          OnboardingColors.primaryGold.withOpacity(0.1),
                          OnboardingColors.primaryGold.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: OnboardingColors.primaryGold.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: OnboardingColors.primaryGold.withOpacity(
                              0.15,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_user,
                            color: OnboardingColors.primaryGold,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Earn Verified Badge',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Verified profiles get 3x more matches',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Selfie Verification
                  const SectionTitle(
                    title: 'Selfie Verification',
                    subtitle: 'Take a clear selfie to verify your identity',
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _takeSelfie,
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: OnboardingColors.fieldBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selfieFile != null
                              ? Colors.green.withOpacity(0.5)
                              : OnboardingColors.primaryGold.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: _selfieFile != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.file(
                                    _selfieFile!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Captured',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 10,
                                  right: 10,
                                  child: GestureDetector(
                                    onTap: _takeSelfie,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.refresh,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_front,
                                  color: OnboardingColors.primaryGold
                                      .withOpacity(0.5),
                                  size: 48,
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Tap to take a selfie',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Required',
                                  style: TextStyle(
                                    color: OnboardingColors.primaryGold
                                        .withOpacity(0.6),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ID Verification
                  const SectionTitle(
                    title: 'ID Verification',
                    subtitle:
                        'Upload a government-issued ID for enhanced trust',
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _uploadID,
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: OnboardingColors.fieldBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _idFile != null
                              ? Colors.green.withOpacity(0.5)
                              : Colors.white12,
                        ),
                      ),
                      child: _idFile != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.file(
                                    _idFile!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Uploaded',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.badge_outlined,
                                  color: Colors.white24,
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Upload Government ID',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Passport, Driver\'s License, etc.',
                                      style: TextStyle(
                                        color: Colors.white24,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Required',
                                      style: TextStyle(
                                        color: OnboardingColors.primaryGold
                                            .withOpacity(0.6),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          NextButton(label: 'Next', onPressed: _handleNext),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
