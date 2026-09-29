import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../../models/onboarding_data.dart';
import '../../../../shared/widgets/onboarding_widgets.dart';
import '../../../../shared/widgets/linear_message.dart';

/// Trimmed per the simplified onboarding spec: the photo-grid review and the
/// profession/education summary are gone (those fields are no longer
/// collected during required onboarding). A video-preview tile replaces them,
/// with a "Retake" affordance that jumps back to the intro-video step. A
/// dedicated Bio & Interests summary card and a live Terms of
/// Service/Privacy Policy checkbox were added back per a later user-feedback
/// follow-up — the checkbox requires this widget to hold local interactive
/// state, so it is a StatefulWidget (was previously a StatelessWidget).
class OnboardingStep7Review extends StatefulWidget {
  final OnboardingData data;
  final Function(int stepIndex) onEditStep;
  final VoidCallback onComplete;
  final bool isLoading;

  const OnboardingStep7Review({
    super.key,
    required this.data,
    required this.onEditStep,
    required this.onComplete,
    required this.isLoading,
  });

  @override
  State<OnboardingStep7Review> createState() => _OnboardingStep7ReviewState();
}

class _OnboardingStep7ReviewState extends State<OnboardingStep7Review> {
  // Step indices in the 7-step flow: 0 Welcome, 1 Basic Info,
  // 2 Intent & Preferences, 3 Bio & Interests, 4 Intro Video,
  // 5 Verification, 6 Review.
  static const int _basicInfoStep = 1;
  static const int _intentPreferencesStep = 2;
  static const int _bioInterestsStep = 3;
  static const int _introVideoStep = 4;
  static const int _verificationStep = 5;

  late bool _termsAccepted;
  // Set once Submit is tapped with something missing: those items turn red.
  bool _showErrors = false;
  final _videoKey = GlobalKey();
  final _verificationKey = GlobalKey();
  final _termsKey = GlobalKey();

  OnboardingData get data => widget.data;

  @override
  void initState() {
    super.initState();
    _termsAccepted = widget.data.termsAccepted;
  }

  void _onTermsToggled(bool? value) {
    final accepted = value ?? false;
    setState(() => _termsAccepted = accepted);
    widget.data.termsAccepted = accepted;
    if (accepted) {
      widget.data.termsAcceptedAt = DateTime.now();
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  bool get _hasVideo {
    final path = data.introVideoLocalPath;
    return path != null && path.isNotEmpty && File(path).existsSync();
  }

  bool get _hasSelfie =>
      data.verificationPhotoUrl.isNotEmpty &&
      File(data.verificationPhotoUrl).existsSync();

  bool get _hasIdPhoto =>
      data.idVerificationUrl.isNotEmpty &&
      File(data.idVerificationUrl).existsSync();

  bool get _hasVerification => _hasSelfie;

  /// Submit is always tappable (a greyed-out button didn't tell users why):
  /// list what's missing, highlight it and scroll to the first item.
  void _handleSubmit() {
    if (widget.isLoading) return;
    final missing = <String>[
      if (!_hasVideo) 'record your intro video',
      if (!_hasVerification) 'take your selfie',
      if (!_termsAccepted) 'accept the Terms & Privacy Policy',
    ];
    if (missing.isEmpty) {
      widget.onComplete();
      return;
    }
    setState(() => _showErrors = true);
    showLinearMessage(
      context,
      'Please ${missing.join(', ')} to continue',
      isError: true,
    );
    final firstKey = !_hasVideo
        ? _videoKey
        : !_hasVerification
            ? _verificationKey
            : _termsKey;
    final target = firstKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
        alignment: 0.1,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review Your Profile',
            style: TextStyle(
              color: OnboardingColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Confirm your details before we send your intro video for review.',
            style: TextStyle(
              color: OnboardingColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          // Card 1: Basic Identity
          _buildSummaryCard(
            title: 'Basic Identity',
            stepIndex: _basicInfoStep,
            icon: Icons.person_rounded,
            items: [
              'Name: ${data.fullName}',
              'Age / Gender: ${data.age ?? 'Not set'} yrs / ${data.gender}',
              'Location: ${data.location}',
            ],
          ),
          const SizedBox(height: 14),

          // Card 2: Intent & Preferences
          _buildSummaryCard(
            title: 'Intent & Preferences',
            stepIndex: _intentPreferencesStep,
            icon: Icons.favorite_rounded,
            items: [
              'Looking for: ${data.lookingFor.isNotEmpty ? data.lookingFor : "Not set"}',
              'Age Range: ${data.minAgePreference} – ${data.maxAgePreference} yrs',
              if (data.partnerPreference.isNotEmpty)
                'Show me: ${data.partnerPreference}',
            ],
          ),
          const SizedBox(height: 14),

          // Card 3: Bio & Interests (with a small profile-photo thumbnail,
          // when one was added on that step)
          _buildSummaryCard(
            title: 'Bio & Interests',
            stepIndex: _bioInterestsStep,
            icon: Icons.chat_bubble_outline_rounded,
            leading: _buildProfilePhotoThumbnail(),
            items: [
              data.bio.isNotEmpty
                  ? (data.bio.length > 120
                      ? '${data.bio.substring(0, 120)}…'
                      : data.bio)
                  : 'No bio added',
              data.interests.isNotEmpty
                  ? 'Interests: ${data.interests.join(', ')}'
                  : 'No interests selected',
            ],
          ),
          const SizedBox(height: 14),

          // Card 4: Intro Video preview (replaces the old photo-grid section)
          KeyedSubtree(key: _videoKey, child: _buildVideoCard(context)),
          const SizedBox(height: 14),

          // Card 5: Verification (selfie required; government ID optional) preview
          KeyedSubtree(
            key: _verificationKey,
            child: _buildVerificationCard(context),
          ),
          const SizedBox(height: 12),

          if (!_hasVideo) ...[
            Text(
              'Record your intro video to continue.',
              style: TextStyle(
                color: _showErrors ? Colors.redAccent : Colors.orangeAccent,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (!_hasVerification) ...[
            Text(
              'Capture your selfie to continue. Government ID is optional.',
              style: TextStyle(
                color: _showErrors ? Colors.redAccent : Colors.orangeAccent,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Terms of Service / Privacy Policy — live checkbox, toggled and
          // persisted to `data.termsAccepted`/`termsAcceptedAt` immediately
          // (not deferred to a later handler).
          Container(
            key: _termsKey,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: OnboardingColors.fieldBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showErrors && !_termsAccepted
                    ? Colors.redAccent
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _termsAccepted,
                  activeColor: OnboardingColors.primaryGold,
                  onChanged: _onTermsToggled,
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: OnboardingColors.textSecondary,
                        fontSize: 12,
                      ),
                      children: [
                        const TextSpan(text: 'I accept the '),
                        TextSpan(
                          text: 'Terms of Service',
                          style: const TextStyle(
                            color: OnboardingColors.primaryGold,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () =>
                                _launchUrl('https://www.swan-match.com/terms'),
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: const TextStyle(
                            color: OnboardingColors.primaryGold,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => _launchUrl(
                                  'https://www.swan-match.com/privacy',
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!_termsAccepted) ...[
            const SizedBox(height: 8),
            Text(
              'Please accept the Terms of Service and Privacy Policy to continue.',
              style: TextStyle(
                color: _showErrors ? Colors.redAccent : Colors.orangeAccent,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 16),

          NextButton(
            label: 'Submit for Review',
            isLoading: widget.isLoading,
            onPressed: _handleSubmit,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OnboardingColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.videocam_rounded, color: OnboardingColors.primaryGold, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Intro Video',
                  style: TextStyle(
                    color: OnboardingColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              InkWell(
                onTap: () => widget.onEditStep(_introVideoStep),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, color: OnboardingColors.primaryGold, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Retake',
                        style: TextStyle(
                          color: OnboardingColors.primaryGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _VideoPreviewTile(localPath: data.introVideoLocalPath),
        ],
      ),
    );
  }

  Widget _buildVerificationCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OnboardingColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: OnboardingColors.primaryGold, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Verification',
                  style: TextStyle(
                    color: OnboardingColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              InkWell(
                onTap: () => widget.onEditStep(_verificationStep),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, color: OnboardingColors.primaryGold, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Retake',
                        style: TextStyle(
                          color: OnboardingColors.primaryGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _VerificationThumbnail(
                  localPath: _hasSelfie ? data.verificationPhotoUrl : null,
                  emptyLabel: 'No selfie',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _VerificationThumbnail(
                  localPath: _hasIdPhoto ? data.idVerificationUrl : null,
                  emptyLabel: 'ID optional',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Small circular thumbnail of the picked profile photo (added on the
  /// Bio & Interests step, see `onboarding_step_bio_interests.dart`), shown
  /// next to that step's summary card. Returns null (card falls back to no
  /// leading widget) when no photo was picked.
  Widget? _buildProfilePhotoThumbnail() {
    final path = data.photos.isNotEmpty ? data.photos.first : data.profilePicture;
    if (path.isEmpty || path.startsWith('http') || !File(path).existsSync()) {
      return null;
    }
    return ClipOval(
      child: Image.file(
        File(path),
        width: 40,
        height: 40,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required int stepIndex,
    required IconData icon,
    required List<String> items,
    Widget? leading,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OnboardingColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) ...[
                SizedBox(width: 40, height: 40, child: leading),
                const SizedBox(width: 10),
              ] else ...[
                Icon(icon, color: OnboardingColors.primaryGold, size: 20),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: OnboardingColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              InkWell(
                onTap: () => widget.onEditStep(stepIndex),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.edit_rounded, color: OnboardingColors.primaryGold, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: TextStyle(
                          color: OnboardingColors.primaryGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $item',
                style: const TextStyle(
                  color: OnboardingColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Small self-contained video preview (thumbnail-ish first frame + tap to
/// play/pause) for the recorded local intro video on the Review step.
class _VideoPreviewTile extends StatefulWidget {
  final String? localPath;

  const _VideoPreviewTile({required this.localPath});

  @override
  State<_VideoPreviewTile> createState() => _VideoPreviewTileState();
}

class _VideoPreviewTileState extends State<_VideoPreviewTile> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    final path = widget.localPath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      final controller = VideoPlayerController.file(File(path));
      controller.initialize().then((_) {
        if (mounted) setState(() {});
      });
      _controller = controller;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'No video recorded',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GestureDetector(
        onTap: _togglePlay,
        child: Container(
          height: 200,
          color: Colors.black,
          child: controller.value.isInitialized
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: VideoPlayer(controller),
                      ),
                    ),
                    if (!controller.value.isPlaying)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                      ),
                  ],
                )
              : const Center(
                  child: CircularProgressIndicator(color: OnboardingColors.primaryGold),
                ),
        ),
      ),
    );
  }
}

/// Small square thumbnail for a captured verification photo (selfie or
/// government ID) on the Review step. Shows a placeholder when missing.
class _VerificationThumbnail extends StatelessWidget {
  final String? localPath;
  final String emptyLabel;

  const _VerificationThumbnail({required this.localPath, required this.emptyLabel});

  @override
  Widget build(BuildContext context) {
    final path = localPath;
    final hasFile = path != null && path.isNotEmpty && File(path).existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 110,
        width: double.infinity,
        color: Colors.black,
        child: hasFile
            ? Image.file(File(path), fit: BoxFit.cover)
            : Center(
                child: Text(
                  emptyLabel,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
      ),
    );
  }
}
