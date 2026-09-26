import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';
import '../../../../services/user_service.dart';
import '../../../../services/storage_service.dart';
import '../../../../services/security_monitoring_service.dart';
import '../../../../models/onboarding_data.dart';
import '../../../../shared/widgets/onboarding_widgets.dart';

import 'onboarding_step1_welcome.dart';
import 'onboarding_step2_basic_info.dart';
import 'onboarding_step_intent_preferences.dart';
import 'onboarding_step_bio_interests.dart';
import 'onboarding_step_intro_video.dart';
import 'onboarding_step_verification.dart';
import 'onboarding_step7_review.dart';
import 'onboarding_pending_review_page.dart';
// `onboarding_step3_intent.dart`, `onboarding_step4_about_you.dart`,
// `onboarding_step5_values.dart`, and `onboarding_step6_preferences.dart` are
// no longer part of the required onboarding flow (replaced by
// `onboarding_step_intent_preferences.dart` + `onboarding_step_intro_video.dart`
// per the simplified onboarding spec). Their files are intentionally NOT
// deleted yet — retained for potential reuse as optional profile-editing
// screens (profession/education/bio/values/dealbreakers), a later, separate
// task.

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
  bool _showProfileReadySuccess = false;
  OnboardingData _onboardingData = OnboardingData();
  String _preparingText = 'Building your Marriage Profile…';

  // 7-step flow: Welcome → Basic Info → Intent & Preferences → Bio &
  // Interests → Intro Video → Verification → Review ("Bio & Interests" added
  // after the onboarding-simplification spec's 6-step flow, per user-feedback
  // follow-up to (re-)collect an optional bio + interests during onboarding).
  static const int _totalSteps = 7;
  static const int _bioInterestsStepIndex = 3;
  static const int _introVideoStepIndex = 4;
  static const int _verificationStepIndex = 5;

  final List<String> _stepTitles = [
    'Welcome',
    'Basic Info',
    'Intent & Preferences',
    'About You',
    'Intro Video',
    'Verification',
    'Review',
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
      _saveProgress();
    }
  }

  String _draftKey(String suffix, String uid) => 'onboarding_${suffix}_$uid';

  Future<void> _persistLocalDraftMedia(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _draftKey('local_photos', uid),
      _onboardingData.photos,
    );
    await prefs.setString(
      _draftKey('profile_picture', uid),
      _onboardingData.profilePicture,
    );
    await prefs.setString(
      _draftKey('verification_photo', uid),
      _onboardingData.verificationPhotoUrl,
    );
    await prefs.setString(
      _draftKey('id_photo', uid),
      _onboardingData.idVerificationUrl,
    );
  }

  Future<void> _restoreLocalDraftMedia(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedPhotos = prefs.getStringList(_draftKey('local_photos', uid)) ?? [];
    final validPhotos = cachedPhotos
        .where((path) => File(path).existsSync())
        .toList();

    if (_onboardingData.photos.isEmpty && validPhotos.isNotEmpty) {
      _onboardingData.photos = validPhotos;
    }

    if (_onboardingData.profilePicture.isEmpty &&
        _onboardingData.photos.isNotEmpty) {
      _onboardingData.profilePicture = _onboardingData.photos.first;
    }
  }

  Future<void> _clearLocalDraftMedia(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey('local_photos', uid));
    await prefs.remove(_draftKey('profile_picture', uid));
    await prefs.remove(_draftKey('verification_photo', uid));
    await prefs.remove(_draftKey('id_photo', uid));
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

      _onboardingData.phone = user.phoneNumber ?? '';
      _onboardingData.email = user.email ?? '';

      final profile = await UserService.instance.getUserProfile(user.uid);
      if (profile != null) {
        _onboardingData = OnboardingData.fromMap(profile);
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
      await _restoreLocalDraftMedia(user.uid);
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
      await _persistLocalDraftMedia(user.uid);
      final data = _onboardingData.toMap();
      data.remove('photos');
      data.remove('profilePicture');
      data.remove('verificationPhotoUrl');
      data.remove('idVerificationUrl');
      // Video fields are only ever written by the explicit upload+complete
      // flow (_completeOnboarding), never by this periodic draft autosave.
      // Rules only permit introVideoStatus == 'pending' from the owner — the
      // '' (not yet submitted) default would trip the rule and deny the
      // ENTIRE write on every autosave before the user reaches that step.
      data.remove('introVideoUrl');
      data.remove('introVideoThumbnailUrl');
      data.remove('introVideoStatus');
      data.remove('introVideoSubmittedAt');

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
      // introVideoRejectionReason is admin-only in Firestore rules — the
      // owner may never touch this key, not even to write null. Including
      // it (even unset) trips the rule and denies the ENTIRE write.
      data.remove('introVideoRejectionReason');

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

  void _jumpToStep(int stepIndex) {
    if (stepIndex >= 0 && stepIndex < _totalSteps) {
      setState(() => _currentStep = stepIndex);
      _pageController.animateToPage(
        stepIndex,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  // ─── Complete onboarding: upload photos + save profile ──────────────────
  Future<void> _completeOnboarding() async {
    // Defense-in-depth against double-submission (the Submit button already
    // disables itself while _isCompleting is true, but guard here too in
    // case of a race, e.g. a queued tap landing right as loading starts).
    if (_isCompleting) return;

    // The profile photo is now mandatory (per user feedback). The picked
    // local path is cached across app restarts via `_persistLocalDraftMedia`
    // (same convention as the verification photos below), so this should
    // only trip if the cached file was somehow removed from disk.
    final photoPath = _onboardingData.profilePicture.isNotEmpty
        ? _onboardingData.profilePicture
        : (_onboardingData.photos.isNotEmpty ? _onboardingData.photos.first : '');
    final hasLocalPhotoFile =
        photoPath.isNotEmpty && File(photoPath).existsSync();
    if (!hasLocalPhotoFile) {
      _showError('Please add a profile photo to continue.');
      _jumpToStep(_bioInterestsStepIndex);
      return;
    }

    // The intro video is mandatory and is only ever set on this device,
    // in-memory (introVideoLocalPath is intentionally not persisted across
    // app restarts, same as local photo paths pre-upload). If it's missing
    // — e.g. the app was killed/restarted after recording but before
    // submitting — attempting to complete anyway would write
    // introVideoStatus as '' instead of 'pending', which Firestore rules
    // reject outright (denying the ENTIRE write, not just that field).
    // Catch this up front with a clear, actionable message instead.
    final localVideoPath = _onboardingData.introVideoLocalPath;
    final hasLocalVideoFile = localVideoPath != null &&
        localVideoPath.isNotEmpty &&
        File(localVideoPath).existsSync();
    if (!hasLocalVideoFile) {
      _showError('Your intro video wasn\'t found. Please record it again.');
      _jumpToStep(_introVideoStepIndex);
      return;
    }

    // Selfie is required; government ID is optional (Guideline 5.1.1v).
    final selfiePath = _onboardingData.verificationPhotoUrl;
    final idPath = _onboardingData.idVerificationUrl;
    final hasLocalSelfieFile =
        selfiePath.isNotEmpty && File(selfiePath).existsSync();
    final hasLocalIdFile = idPath.isNotEmpty && File(idPath).existsSync();
    if (!hasLocalSelfieFile) {
      _showError(
        'Your verification selfie wasn\'t found. Please capture it again.',
      );
      _jumpToStep(_verificationStepIndex);
      return;
    }

    // Terms of Service / Privacy Policy acceptance is a required, live-toggled
    // checkbox on the Review step itself (see onboarding_step7_review.dart) —
    // if it's somehow unset when this fires (e.g. a queued submit tap), abort
    // and jump back to that same step rather than writing a profile without
    // recorded consent.
    if (!_onboardingData.termsAccepted) {
      _showError(
        'Please accept the Terms of Service and Privacy Policy to continue.',
      );
      _jumpToStep(_totalSteps - 1);
      return;
    }

    setState(() {
      _isCompleting = true;
      _showProfileReadySuccess = false;
      _preparingText = 'Setting up your profile…';
    });

    Timer? cycleTimer;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('Authentication error. Please sign in again.');
        setState(() => _isCompleting = false);
        return;
      }

      // Fast, responsive AI analysis sequence (~10 seconds)
      final delayFuture = Future.delayed(const Duration(seconds: 10));

      int elapsedSeconds = 0;
      cycleTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        elapsedSeconds++;
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          if (elapsedSeconds >= 8) {
            _preparingText = 'Almost there…';
          } else if (elapsedSeconds >= 6) {
            _preparingText = 'Uploading your intro video…';
          } else if (elapsedSeconds >= 3) {
            _preparingText = 'Saving your details…';
          }
        });
      });

      // 1. Prepare photo upload tasks (photos are now optional/secondary —
      // min 0, was min 3 — so this must not break when `_localPhotos`/
      // `photos` is empty).
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

      // 2. Prepare intro video upload task, parallel to the photo uploads.
      Future<String?> videoUploadTask = Future.value(null);
      final videoLocalPath = _onboardingData.introVideoLocalPath;
      if (videoLocalPath != null && videoLocalPath.isNotEmpty) {
        final videoFile = File(videoLocalPath);
        videoUploadTask = videoFile.exists().then((exists) async {
          if (!exists) return null;
          try {
            return await StorageService.instance.uploadIntroVideo(
              uid: user.uid,
              file: videoFile,
              onProgress: (progress) {
                if (!mounted) return;
                final percent = (progress.clamp(0.0, 1.0) * 100).round();
                setState(() {
                  _preparingText = 'Uploading your intro video… $percent%';
                });
              },
            );
          } catch (e) {
            debugPrint('Error uploading intro video: $e');
            return null;
          }
        });
      }

      // 2b. Prepare intro video thumbnail upload task, best-effort — a
      // nice-to-have instant preview image, not required for onboarding to
      // complete. Never let a thumbnail failure block or fail the overall
      // completion (unlike the video upload itself, which is mandatory).
      Future<String?> thumbnailUploadTask = Future.value(null);
      final thumbnailLocalPath = _onboardingData.introVideoThumbnailLocalPath;
      if (thumbnailLocalPath != null && thumbnailLocalPath.isNotEmpty) {
        final thumbnailFile = File(thumbnailLocalPath);
        thumbnailUploadTask = thumbnailFile.exists().then((exists) async {
          if (!exists) return null;
          try {
            return await StorageService.instance.uploadIntroVideoThumbnail(
              uid: user.uid,
              file: thumbnailFile,
            );
          } catch (e) {
            debugPrint('Error uploading intro video thumbnail: $e');
            return null;
          }
        });
      }

      // 3. Prepare verification photo upload tasks.
      // Selfie is required; government ID is optional (Guideline 5.1.1v).
      final selfieFile = File(_onboardingData.verificationPhotoUrl);
      final Future<String?> selfieUploadTask = () async {
        try {
          return await StorageService.instance.uploadVerificationFile(
            uid: user.uid,
            file: selfieFile,
            kind: 'selfie',
          );
        } catch (e) {
          debugPrint('Error uploading verification selfie: $e');
          return null;
        }
      }();

      final Future<String?> idUploadTask = hasLocalIdFile
          ? () async {
              try {
                return await StorageService.instance.uploadVerificationFile(
                  uid: user.uid,
                  file: File(idPath),
                  kind: 'government_id',
                );
              } catch (e) {
                debugPrint('Error uploading verification ID: $e');
                return null;
              }
            }()
          : Future<String?>.value(null);

      final results = await Future.wait<dynamic>([
        Future.wait(photoUploadTasks),
        videoUploadTask,
        selfieUploadTask,
        idUploadTask,
        thumbnailUploadTask,
      ]);

      final List<String?> rawPhotoUrls = results[0] as List<String?>;
      final List<String> uploadedUrls = rawPhotoUrls.whereType<String>().toList();
      String profilePictureUrl = uploadedUrls.isNotEmpty ? uploadedUrls.first : '';
      final String? uploadedVideoUrl = results[1] as String?;
      final String? uploadedSelfieUrl = results[2] as String?;
      final String? uploadedIdUrl = results[3] as String?;
      final String? uploadedThumbnailUrl = results[4] as String?;

      // We already confirmed a local video file exists (see the guard at the
      // top of this method) — if the upload itself still failed (e.g. a
      // network blip), do NOT proceed to write the profile: writing without
      // introVideoStatus set to 'pending' would trip the security rule and
      // deny the whole write, and writing the rest of the profile without a
      // video would leave the account in a broken, incomplete state (video
      // is mandatory for this app). Fail loudly and let the user retry.
      if (uploadedVideoUrl == null || uploadedVideoUrl.isEmpty) {
        _showError('Uploading your intro video failed. Please check your connection and try again.');
        setState(() => _isCompleting = false);
        return;
      }

      // Selfie is required; government ID is optional — only fail if selfie upload fails.
      if (uploadedSelfieUrl == null || uploadedSelfieUrl.isEmpty) {
        _showError('Uploading your verification selfie failed. Please check your connection and try again.');
        setState(() => _isCompleting = false);
        return;
      }
      // Optional ID: if user provided one but upload failed, warn but do not block.
      if (hasLocalIdFile &&
          (uploadedIdUrl == null || uploadedIdUrl.isEmpty)) {
        debugPrint(
          'Optional government ID upload failed; continuing without ID.',
        );
      }

      // Build final profile data with structured marriageProfile
      final data = _onboardingData.toMap();
      data['uid'] = user.uid;
      data['name'] = _onboardingData.fullName;
      data['photos'] = uploadedUrls;
      data['images'] = uploadedUrls;
      data['profilePicture'] = profilePictureUrl;
      data['location'] = _onboardingData.location;
      data['age'] = _onboardingData.age ?? 0;
      data['highestQualification'] = _onboardingData.educationLevel;
      data['registrationCompleted'] = true;
      data['onboardingStep'] = _totalSteps;

      // uploadedVideoUrl is guaranteed non-empty here (checked above).
      data['introVideoUrl'] = uploadedVideoUrl;
      data['introVideoStatus'] = 'pending';
      data['introVideoSubmittedAt'] = FieldValue.serverTimestamp();
      // Thumbnail is best-effort — only set it if the upload actually
      // succeeded; otherwise leave whatever `toMap()` already put in `data`
      // (empty string) rather than writing a broken/missing value here.
      if (uploadedThumbnailUrl != null && uploadedThumbnailUrl.isNotEmpty) {
        data['introVideoThumbnailUrl'] = uploadedThumbnailUrl;
      }

      // uploadedSelfieUrl / uploadedIdUrl are guaranteed non-empty here
      // (checked above) — overwrite the local-path values `toMap()` put in
      // `data` with the actual uploaded URLs. `verificationStatus` is a
      // rule-restricted field: the owner may only ever set it to exactly
      // 'pending' (see firestore.rules), which is exactly what's needed here.
      data['verificationPhotoUrl'] = uploadedSelfieUrl;
      if (uploadedIdUrl != null && uploadedIdUrl.isNotEmpty) {
        data['idVerificationUrl'] = uploadedIdUrl;
      } else {
        data['idVerificationUrl'] = '';
      }
      data['verificationStatus'] = 'pending';
      data['idVerified'] = false;
      data['profileVerified'] = false;
      data['verificationSubmittedAt'] = FieldValue.serverTimestamp();

      data.remove('account');
      data.remove('isVerified');
      // NOTE: 'verificationStatus' is intentionally NOT removed here (unlike
      // the periodic draft autosave in _saveProgress()) — it's deliberately
      // set to 'pending' above now that verification is a required
      // onboarding step, mirroring how introVideoStatus is set just above.
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
      // introVideoRejectionReason is admin-only in Firestore rules — the
      // owner may never touch this key, not even to write null. Including
      // it (even unset) trips the rule and denies the ENTIRE write.
      data.remove('introVideoRejectionReason');

      await UserService.instance.upsertUserProfile(uid: user.uid, data: data);
      await _clearLocalDraftMedia(user.uid);

      unawaited(SecurityMonitoringService.instance.logSessionActivity('marriage_onboarding_completed'));

      await delayFuture;

      if (mounted) {
        setState(() {
          _preparingText = 'Your profile is ready.';
          _showProfileReadySuccess = true;
        });
      }
    } catch (e) {
      debugPrint('Onboarding completion error: $e');
      _showError('Onboarding completion error: $e');
      if (mounted) setState(() => _isCompleting = false);
    } finally {
      cycleTimer?.cancel();
    }
  }

  void _proceedToApp() {
    // Route through the intro-video pending-review screen instead of jumping
    // straight to FreeTrialPage — FreeTrialPage remains the eventual
    // destination, reached from there once the user acknowledges.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingPendingReviewPage()),
      (route) => false,
    );
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
                      OnboardingStep1Welcome(
                        data: _onboardingData,
                        onNext: _goToNext,
                      ),
                      OnboardingStep2BasicInfo(
                        data: _onboardingData,
                        onNext: _goToNext,
                        onBack: _goBack,
                      ),
                      OnboardingStepIntentPreferences(
                        data: _onboardingData,
                        onNext: _goToNext,
                        onBack: _goBack,
                      ),
                      OnboardingStepBioInterests(
                        data: _onboardingData,
                        onNext: _goToNext,
                        onBack: _goBack,
                      ),
                      OnboardingStepIntroVideo(
                        data: _onboardingData,
                        onNext: _goToNext,
                        onBack: _goBack,
                      ),
                      OnboardingStepVerification(
                        data: _onboardingData,
                        onNext: _goToNext,
                        onBack: _goBack,
                      ),
                      OnboardingStep7Review(
                        data: _onboardingData,
                        onEditStep: _jumpToStep,
                        onComplete: _completeOnboarding,
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
      child: Stack(
        children: [
          // Blurred background — absorbs touches so underlying page is blocked
          Positioned.fill(
            child: AbsorbPointer(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    color: OnboardingColors.background.withOpacity(0.95),
                  ),
                ),
              ),
            ),
          ),
          // Foreground content — NOT wrapped in AbsorbPointer so taps work
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_showProfileReadySuccess) ...[
                    const CircularProgressIndicator(
                      color: OnboardingColors.primaryGold,
                      strokeWidth: 3,
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
                      'Just a moment while we get everything ready',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: OnboardingColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: OnboardingColors.primaryGold.withOpacity(0.2),
                        border: Border.all(color: OnboardingColors.primaryGold, width: 2),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: OnboardingColors.primaryGold,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Your Profile is Ready!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: OnboardingColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your intro video is under review. Once it\'s approved, you\'ll appear in Discover and can start connecting.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: OnboardingColors.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    NextButton(
                      label: 'Continue',
                      onPressed: _proceedToApp,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
      child: Column(
        children: [
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
