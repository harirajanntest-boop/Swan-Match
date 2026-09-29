import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../models/onboarding_data.dart';
import '../../../../shared/widgets/onboarding_widgets.dart';
import '../../../../shared/widgets/linear_message.dart';

/// "Bio & Interests" onboarding step, inserted between Intent & Preferences
/// and Intro Video. Bio and interests remain optional, matching the "keep
/// onboarding simple" philosophy established for the rest of the required
/// flow (see OnboardingStepIntentPreferences / OnboardingStep2BasicInfo) —
/// but the profile photo is required (per user feedback), so "Continue" is
/// gated on a photo having been picked.
///
/// The profile-photo picker added here (per user feedback: photo upload was
/// dropped from onboarding entirely during an earlier redesign, and users
/// want it asked during the flow rather than only later via Profile > Edit
/// Profile) writes the picked local file path into `data.photos` (as the
/// first/only entry) and `data.profilePicture` — the exact same fields
/// `onboarding_flow.dart`'s `_completeOnboarding()` already uploads via
/// `StorageService.instance.uploadProfilePhoto`, so no changes were needed
/// there. Follows the same `image_picker` pattern used by
/// `edit_profile_page.dart`'s photo section.
///
/// Reuses the exact `_interestOptions` list from edit_profile_page.dart for
/// visual/data consistency with the profile-editing screen, but follows this
/// flow's own GoldChip + Wrap multi-select convention (as used for "Languages
/// Spoken" in OnboardingStep2BasicInfo) rather than edit_profile_page's
/// FilterChip + AlertDialog pattern.
class OnboardingStepBioInterests extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingStepBioInterests({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<OnboardingStepBioInterests> createState() =>
      _OnboardingStepBioInterestsState();
}

class _OnboardingStepBioInterestsState
    extends State<OnboardingStepBioInterests> {
  late TextEditingController _bioCtrl;
  late List<String> _selectedInterests;
  String? _localPhotoPath;
  // Set once Continue is tapped without a photo: the photo turns red.
  bool _showErrors = false;
  final _photoKey = GlobalKey();
  bool _pickingPhoto = false;

  // Kept identical to edit_profile_page.dart's `_interestOptions` for
  // visual/data consistency between onboarding and profile editing.
  static const List<String> _interestOptions = [
    'Travel', 'Reading', 'Music', 'Cooking', 'Photography', 'Sports', 'Art',
    'Technology', 'Movies', 'Yoga & Meditation', 'Dancing', 'Hiking', 'Gaming',
    'Volunteering', 'Fashion', 'Gardening', 'Writing', 'Fitness',
  ];

  @override
  void initState() {
    super.initState();
    _bioCtrl = TextEditingController(text: widget.data.bio);
    _selectedInterests = List<String>.from(widget.data.interests);

    // Pre-fill from whatever's already in `data` (e.g. the user navigated
    // back to this step after picking a photo, or a resumed draft).
    final existingPhoto = widget.data.photos.isNotEmpty
        ? widget.data.photos.first
        : widget.data.profilePicture;
    if (existingPhoto.isNotEmpty && !existingPhoto.startsWith('http')) {
      _localPhotoPath = existingPhoto;
    }
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    super.dispose();
  }

  void _saveAndNext() {
    FocusManager.instance.primaryFocus?.unfocus();
    // Continue is always tappable (a greyed-out button didn't tell users
    // why) — say what's missing and take them to it.
    if (_localPhotoPath == null) {
      setState(() => _showErrors = true);
      showLinearMessage(
        context,
        'Please add a profile photo to continue',
        isError: true,
      );
      final target = _photoKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 300),
          alignment: 0.1,
        );
      }
      return;
    }
    widget.data.bio = _bioCtrl.text.trim();
    widget.data.interests = List<String>.from(_selectedInterests);
    widget.onNext();
  }

  void _setPhoto(String path) {
    setState(() => _localPhotoPath = path);
    widget.data.photos = [path];
    widget.data.profilePicture = path;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1080,
      );
      if (file != null && file.path.isNotEmpty) {
        _setPhoto(file.path);
      }
    } catch (_) {
      // Best-effort — the picker is optional, so silently ignore failures
      // (e.g. permission denied) rather than blocking the step.
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _showPhotoSourceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: OnboardingColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: OnboardingColors.primaryGold),
                title: const Text('Choose from Gallery',
                    style: TextStyle(color: OnboardingColors.textPrimary)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickPhoto(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: OnboardingColors.primaryGold),
                title: const Text('Take a Photo',
                    style: TextStyle(color: OnboardingColors.textPrimary)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickPhoto(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
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
            'About You',
            style: TextStyle(
              color: OnboardingColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add a profile photo, then share a bit about yourself — bio and interests are optional.',
            style: TextStyle(
              color: OnboardingColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          // Profile photo (required per user feedback — photo upload was
          // previously dropped from onboarding entirely and is now asked
          // here, the most natural "About You" step, rather than only later
          // via Profile > Edit Profile).
          Text(
            'Profile photo (required)',
            key: _photoKey,
            style: TextStyle(
              color: OnboardingColors.primaryGold.withOpacity(0.9),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: _pickingPhoto ? null : _showPhotoSourceSheet,
              child: Stack(
                children: [
                  Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: OnboardingColors.fieldBackground,
                      border: Border.all(
                        color: _showErrors && _localPhotoPath == null
                            ? Colors.redAccent
                            : OnboardingColors.primaryGold.withOpacity(0.6),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: _localPhotoPath != null
                          ? Image.file(
                              File(_localPhotoPath!),
                              fit: BoxFit.cover,
                              width: 108,
                              height: 108,
                            )
                          : Icon(
                              Icons.add_a_photo_outlined,
                              color: OnboardingColors.primaryGold
                                  .withOpacity(0.7),
                              size: 32,
                            ),
                    ),
                  ),
                  if (_pickingPhoto)
                    const Positioned.fill(
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: OnboardingColors.primaryGold,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: OnboardingColors.primaryGold,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _localPhotoPath != null
                            ? Icons.edit_rounded
                            : Icons.add_rounded,
                        color: Colors.black,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_localPhotoPath == null) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Tap the circle to add a photo — required to continue.',
                style: TextStyle(
                  color: _showErrors
                      ? Colors.redAccent
                      : OnboardingColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),

          // Bio (optional)
          Row(
            children: [
              const Text(
                'Bio',
                style: TextStyle(color: OnboardingColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(width: 6),
              Text(
                '(Optional)',
                style: TextStyle(
                  color: OnboardingColors.primaryGold.withOpacity(0.8),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          UnderlineTextField(
            label: null,
            hint: 'What are you looking for? Tell people a bit about yourself.',
            controller: _bioCtrl,
            maxLines: 3,
            maxLength: 300,
          ),
          const SizedBox(height: 28),

          // Interests (optional, multi-select chips)
          const Text(
            'Interests (optional, select a few)',
            style: TextStyle(color: OnboardingColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _interestOptions.map((interest) {
              final selected = _selectedInterests.contains(interest);
              return GoldChip(
                label: interest,
                selected: selected,
                showCheckmark: true,
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedInterests.remove(interest);
                    } else {
                      _selectedInterests.add(interest);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 36),

          NextButton(
            label: 'Continue',
            onPressed: _saveAndNext,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
