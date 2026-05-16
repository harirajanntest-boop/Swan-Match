import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../../../../services/user_service.dart';
import '../../../../services/storage_service.dart';
import '../../../../models/onboarding_data.dart';
import '../../../../shared/widgets/onboarding_widgets.dart';
import 'onboarding_step1_identity.dart';
import 'onboarding_step2_status.dart';
import 'onboarding_step3_lifestyle.dart';
import 'onboarding_step4_cultural.dart';
import 'onboarding_step5_personality.dart';
import 'onboarding_step6_preferences.dart';
import 'onboarding_step7_verification.dart';
import 'onboarding_step8_exclusivity.dart';
import 'main_dashboard.dart';
import 'free_trial_page.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isCompleting = false;
  OnboardingData _onboardingData = OnboardingData();

  static const int _totalSteps = 8;

  final List<String> _stepTitles = [
    'Basic Identity',
    'Status & Intent',
    'Lifestyle & Career',
    'Cultural & Language',
    'Personality',
    'Partner Preferences',
    'Verification',
    'Exclusivity',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _loadSavedProgress();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // Save progress automatically when the app goes to the background or is killed
      _saveProgress();
    }
  }

  // ─── Load saved progress from Firestore ─────────────────────────────────
  Future<void> _loadSavedProgress() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Pre-fill phone & email from Firebase Auth
      _onboardingData.phone = user.phoneNumber ?? '';
      _onboardingData.email = user.email ?? '';

      // Load existing profile data
      final profile = await UserService.instance.getUserProfile(user.uid);
      if (profile != null) {
        _onboardingData = OnboardingData.fromMap(profile);
        // Re-apply auth data (always latest)
        _onboardingData.phone = user.phoneNumber ?? _onboardingData.phone;
        _onboardingData.email = user.email ?? _onboardingData.email;

        final savedStep = _onboardingData.onboardingStep;
        if (savedStep > 0 && savedStep < _totalSteps) {
          _currentStep = savedStep;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.jumpToPage(savedStep);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading progress: $e');
    }
    setState(() => _isLoading = false);
  }

  // ─── Save progress to Firestore ─────────────────────────────────────────
  Future<void> _saveProgress() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _onboardingData.onboardingStep = _currentStep;
      final data = _onboardingData.toMap();
      // Remove local file paths before saving to Firestore
      data.remove('photos');
      data.remove('profilePicture');
      data.remove('verificationPhotoUrl');
      data.remove('idVerificationUrl');

      await UserService.instance.upsertUserProfile(uid: user.uid, data: data);
    } catch (e) {
      debugPrint('Error saving progress: $e');
    }
  }

  // ─── Navigation ─────────────────────────────────────────────────────────
  void _goToNext() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      _saveProgress();
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  // ─── Complete onboarding: upload photos + save all data ─────────────────
  Future<void> _completeOnboarding() async {
    setState(() => _isCompleting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('Authentication error. Please sign in again.');
        setState(() => _isCompleting = false);
        return;
      }

      // Upload photos to Firebase Storage
      final List<String> uploadedUrls = [];
      String profilePictureUrl = '';

      for (int i = 0; i < _onboardingData.photos.length; i++) {
        final photoPath = _onboardingData.photos[i];
        final file = File(photoPath);

        if (await file.exists()) {
          try {
            final url = await StorageService.instance.uploadProfilePhoto(
              uid: user.uid,
              file: file,
            );
            uploadedUrls.add(url);
            if (i == 0) profilePictureUrl = url;
          } catch (e) {
            debugPrint('Error uploading photo $i: $e');
          }
        } else if (photoPath.startsWith('http')) {
          // Already a URL (from previous upload)
          uploadedUrls.add(photoPath);
          if (i == 0) profilePictureUrl = photoPath;
        }
      }

      // Upload verification selfie
      String verificationUrl = '';
      if (_onboardingData.verificationPhotoUrl.isNotEmpty) {
        final selfieFile = File(_onboardingData.verificationPhotoUrl);
        if (await selfieFile.exists()) {
          try {
            verificationUrl = await StorageService.instance.uploadProfilePhoto(
              uid: user.uid,
              file: selfieFile,
            );
          } catch (e) {
            debugPrint('Error uploading selfie: $e');
          }
        }
      }

      // Upload ID if provided
      String idUrl = '';
      if (_onboardingData.idVerificationUrl.isNotEmpty) {
        final idFile = File(_onboardingData.idVerificationUrl);
        if (await idFile.exists()) {
          try {
            idUrl = await StorageService.instance.uploadProfilePhoto(
              uid: user.uid,
              file: idFile,
            );
          } catch (e) {
            debugPrint('Error uploading ID: $e');
          }
        }
      }

      // Build final profile data
      final data = _onboardingData.toMap();
      data['uid'] = user.uid;
      data['name'] = _onboardingData.fullName;
      data['photos'] = uploadedUrls;
      data['images'] = uploadedUrls;
      data['profilePicture'] = profilePictureUrl;
      data['verificationPhotoUrl'] = verificationUrl;
      data['idVerificationUrl'] = idUrl;
      data['location'] = _onboardingData.location;
      data['age'] = _onboardingData.age ?? 0;
      data['highestQualification'] = _onboardingData.educationLevel;
      data['registrationCompleted'] = true;
      data['onboardingStep'] = _totalSteps;
      data['subscriptionPlan'] = 'free';

      // ── Verification is ALWAYS pending on registration.
      //    Only the Admin Dashboard can promote this to 'approved'.
      data['isVerified'] = false;
      data['idVerified'] = false;
      data['profileVerified'] = false;
      data['profileApprovalStatus'] = 'pending';
      data['verificationStatus'] = 'pending'; // admin sets to 'approved'

      // Save to Firestore
      await UserService.instance.upsertUserProfile(uid: user.uid, data: data);

      // Navigate to the free trial offer page instead of directly to dashboard
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const FreeTrialPage()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Onboarding completion error: $e');
      _showError('Something went wrong. Please try again.');
    }
    if (mounted) setState(() => _isCompleting = false);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: OnboardingColors.background,
        body: Center(
          child: CircularProgressIndicator(color: OnboardingColors.primaryGold),
        ),
      );
    }

    return Scaffold(
      backgroundColor: OnboardingColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header: Back + Step counter + Progress bar ────────────
            _buildHeader(),
            // ─── Page content ──────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  OnboardingStep1Identity(
                    data: _onboardingData,
                    onNext: _goToNext,
                  ),
                  OnboardingStep2Status(
                    data: _onboardingData,
                    onNext: _goToNext,
                    onBack: _goBack,
                  ),
                  OnboardingStep3Lifestyle(
                    data: _onboardingData,
                    onNext: _goToNext,
                    onBack: _goBack,
                  ),
                  OnboardingStep4Cultural(
                    data: _onboardingData,
                    onNext: _goToNext,
                    onBack: _goBack,
                  ),
                  OnboardingStep5Personality(
                    data: _onboardingData,
                    onNext: _goToNext,
                    onBack: _goBack,
                  ),
                  OnboardingStep6Preferences(
                    data: _onboardingData,
                    onNext: _goToNext,
                    onBack: _goBack,
                  ),
                  OnboardingStep7Verification(
                    data: _onboardingData,
                    onNext: _goToNext,
                    onBack: _goBack,
                  ),
                  OnboardingStep8Exclusivity(
                    data: _onboardingData,
                    onComplete: _completeOnboarding,
                    onBack: _goBack,
                    isLoading: _isCompleting,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
      child: Column(
        children: [
          // Top row: back button + step counter
          Row(
            children: [
              if (_currentStep > 0)
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: _goBack,
                )
              else
                const SizedBox(width: 48),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Step ${_currentStep + 1} of $_totalSteps',
                  style: const TextStyle(
                    color: OnboardingColors.primaryGold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(_totalSteps, (index) {
                final isCompleted = index < _currentStep;
                final isCurrent = index == _currentStep;
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: isCompleted
                          ? OnboardingColors.primaryGold
                          : isCurrent
                          ? OnboardingColors.primaryGold.withOpacity(0.5)
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
