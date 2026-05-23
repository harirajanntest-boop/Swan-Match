import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:async';
import '../../../../services/user_service.dart';
import '../../../../services/storage_service.dart';
import '../../../../services/security_monitoring_service.dart';
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
  String _preparingText = 'Analyzing relationship intent…';

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

      // Remove all restricted keys to comply with Firestore rules
      data.remove('account');
      data.remove('isVerified');
      data.remove('verificationStatus');
      data.remove('stripeCustomerId');
      data.remove('stripeSubscriptionId');
      data.remove('lastCheckoutSessionId');
      data.remove('lastInvoiceId');
      data.remove('subscription');
      data.remove('paymentStatus');
      data.remove('customerEmail');
      data.remove('customerName');
      data.remove('billingPeriodStart');
      data.remove('billingPeriodEnd');
      data.remove('subscriptionPriceId');
      data.remove('subscriptionName');

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
    setState(() {
      _isCompleting = true;
      _preparingText = 'Analyzing relationship intent…';
    });

    Timer? cycleTimer;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('Authentication error. Please sign in again.');
        setState(() => _isCompleting = false);
        return;
      }

      // Start the artificial premium delay (31 seconds)
      final delayFuture = Future.delayed(const Duration(seconds: 31));

      // Start a timer to cycle through premium matching preparation stages
      int elapsedSeconds = 0;
      cycleTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        elapsedSeconds++;
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          if (elapsedSeconds >= 24) {
            _preparingText = 'Constructing your exclusive profile…';
          } else if (elapsedSeconds >= 18) {
            _preparingText = 'Calibrating the match engine…';
          } else if (elapsedSeconds >= 12) {
            _preparingText = 'Securing identity & verification data…';
          } else if (elapsedSeconds >= 6) {
            _preparingText = 'Scanning partner preferences…';
          }
        });
      });

      // ─── Parallelize All Uploads ───

      // 1. Prepare profile photo upload tasks
      final List<Future<String?>> photoUploadTasks = [];
      for (int i = 0; i < _onboardingData.photos.length; i++) {
        final photoPath = _onboardingData.photos[i];
        if (photoPath.startsWith('http')) {
          photoUploadTasks.add(Future.value(photoPath));
        } else {
          final file = File(photoPath);
          photoUploadTasks.add(
            file.exists().then((exists) async {
              if (exists) {
                try {
                  return await StorageService.instance.uploadProfilePhoto(
                    uid: user.uid,
                    file: file,
                  );
                } catch (e) {
                  debugPrint('Error uploading photo $i: $e');
                  return null;
                }
              }
              return null;
            }),
          );
        }
      }

      // 2. Prepare verification selfie upload task
      Future<String?> selfieUploadTask = Future.value('');
      if (_onboardingData.verificationPhotoUrl.isNotEmpty) {
        final selfieFile = File(_onboardingData.verificationPhotoUrl);
        if (selfieFile.path.startsWith('http')) {
          selfieUploadTask = Future.value(selfieFile.path);
        } else {
          selfieUploadTask = selfieFile.exists().then((exists) async {
            if (exists) {
              try {
                return await StorageService.instance.uploadProfilePhoto(
                  uid: user.uid,
                  file: selfieFile,
                );
              } catch (e) {
                debugPrint('Error uploading selfie: $e');
                return '';
              }
            }
            return '';
          });
        }
      }

      // 3. Prepare ID verification upload task
      Future<String?> idUploadTask = Future.value('');
      if (_onboardingData.idVerificationUrl.isNotEmpty) {
        final idFile = File(_onboardingData.idVerificationUrl);
        if (idFile.path.startsWith('http')) {
          idUploadTask = Future.value(idFile.path);
        } else {
          idUploadTask = idFile.exists().then((exists) async {
            if (exists) {
              try {
                return await StorageService.instance.uploadProfilePhoto(
                  uid: user.uid,
                  file: idFile,
                );
              } catch (e) {
                debugPrint('Error uploading ID: $e');
                return '';
              }
            }
            return '';
          });
        }
      }

      // 4. Run all uploads in parallel
      final results = await Future.wait([
        Future.wait(photoUploadTasks),
        selfieUploadTask,
        idUploadTask,
      ]);

      final List<String?> rawPhotoUrls = results[0] as List<String?>;
      final String verificationUrl = (results[1] as String?) ?? '';
      final String idUrl = (results[2] as String?) ?? '';

      final List<String> uploadedUrls = rawPhotoUrls.whereType<String>().toList();
      String profilePictureUrl = uploadedUrls.isNotEmpty ? uploadedUrls.first : '';

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

      // Note: We omit 'isVerified', 'verificationStatus', 'subscriptionName' from the update payload.
      // They are already initialized as defaults during signup.
      data.remove('account');
      data.remove('isVerified');
      data.remove('verificationStatus');
      data.remove('stripeCustomerId');
      data.remove('stripeSubscriptionId');
      data.remove('lastCheckoutSessionId');
      data.remove('lastInvoiceId');
      data.remove('subscription');
      data.remove('paymentStatus');
      data.remove('customerEmail');
      data.remove('customerName');
      data.remove('billingPeriodStart');
      data.remove('billingPeriodEnd');
      data.remove('subscriptionPriceId');
      data.remove('subscriptionName');

      if (verificationUrl.isNotEmpty || idUrl.isNotEmpty) {
        data['verificationSubmittedAt'] = FieldValue.serverTimestamp();
      }

      final visibility =
          (_onboardingData.profileVisibility).toString().trim();
      final isPrivate = visibility == 'Private';
      data['showProfileToEveryone'] = !isPrivate;
      data['showPhotosToEveryone'] = data['showPhotosToEveryone'] ?? true;

      // Save to Firestore
      await UserService.instance.upsertUserProfile(uid: user.uid, data: data);

      // Trigger secure background session tracking upon onboarding completion
      unawaited(SecurityMonitoringService.instance.logSessionActivity('onboarding_completed'));

      // Wait for the full 31 seconds duration to complete to build premium anticipation
      await delayFuture;

      // Navigate to the free trial offer page instead of directly to dashboard
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const FreeTrialPage()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Onboarding completion error: $e');
      _showError('Onboarding completion error: $e');
    } finally {
      cycleTimer?.cancel();
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
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
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
          if (_isCompleting) _buildPreparingOverlay(),
        ],
      ),
    );
  }

  Widget _buildPreparingOverlay() {
    return Positioned.fill(
      child: AbsorbPointer(
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: OnboardingColors.background.withOpacity(0.92),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: OnboardingColors.primaryGold,
                      ),
                      const SizedBox(height: 32),
                      Text(
                        _preparingText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: OnboardingColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Swan is customizing your luxury match ecosystem',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: OnboardingColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
