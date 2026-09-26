import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../../models/onboarding_data.dart';
import '../../../../shared/widgets/onboarding_widgets.dart';

class OnboardingStep4AboutYou extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingStep4AboutYou({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<OnboardingStep4AboutYou> createState() => _OnboardingStep4AboutYouState();
}

class _OnboardingStep4AboutYouState extends State<OnboardingStep4AboutYou> {
  late TextEditingController _professionCtrl;
  late TextEditingController _bioCtrl;
  String _educationLevel = 'Bachelors';
  double _heightCm = 175; // ~5'9"
  String _smoking = 'Non-smoker';
  String _drinking = 'Socially';
  String _fitnessLevel = 'Active';
  List<String> _localPhotos = [];
  final ImagePicker _picker = ImagePicker();

  final List<String> _educationLevels = [
    'High School',
    'Bachelors',
    'Masters',
    'Doctorate / PhD',
    'Professional Degree',
    'Other',
  ];

  final List<String> _smokingOptions = [
    'Non-smoker',
    'Occasional',
    'Regular',
  ];

  final List<String> _drinkingOptions = [
    'Non-driller',
    'Socially',
    'Regular',
  ];

  final List<String> _fitnessOptions = [
    'Active',
    'Moderate',
    'Gym Enthusiast',
    'Casual',
  ];

  @override
  void initState() {
    super.initState();
    _professionCtrl = TextEditingController(text: widget.data.profession);
    _bioCtrl = TextEditingController(text: widget.data.bio);
    if (widget.data.educationLevel.isNotEmpty) {
      _educationLevel = widget.data.educationLevel;
    }
    if (widget.data.smoking.isNotEmpty) _smoking = widget.data.smoking;
    if (widget.data.drinking.isNotEmpty) _drinking = widget.data.drinking;
    if (widget.data.workout.isNotEmpty) _fitnessLevel = widget.data.workout;

    if (widget.data.photos.isNotEmpty) {
      _localPhotos = List<String>.from(widget.data.photos);
    }

    // Try parsing existing height string if available (e.g. 175 cm)
    if (widget.data.height.isNotEmpty) {
      final match = RegExp(r'(\d+)').firstMatch(widget.data.height);
      if (match != null) {
        final val = double.tryParse(match.group(1)!);
        if (val != null && val >= 140 && val <= 220) {
          _heightCm = val;
        }
      }
    }
  }

  @override
  void dispose() {
    _professionCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  String _formatHeight(double cm) {
    final inchesTotal = (cm / 2.54).round();
    final feet = inchesTotal ~/ 12;
    final inches = inchesTotal % 12;
    return "$feet'$inches\" (${cm.toInt()} cm)";
  }

  Future<void> _pickPhoto(int index) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() {
        if (index < _localPhotos.length) {
          _localPhotos[index] = image.path;
        } else {
          _localPhotos.add(image.path);
        }
      });
    }
  }

  void _removePhoto(int index) {
    if (index < _localPhotos.length) {
      setState(() => _localPhotos.removeAt(index));
    }
  }

  bool get _isValid {
    final prof = _professionCtrl.text.trim();
    // Photos are optional/secondary now (min 0, was min 3) — this step is no
    // longer part of required onboarding, retained for optional profile editing.
    return prof.isNotEmpty;
  }

  void _saveAndNext() {
    if (!_isValid) return;
    widget.data.profession = _professionCtrl.text.trim();
    widget.data.educationLevel = _educationLevel;
    widget.data.highestQualification = _educationLevel;
    widget.data.height = _formatHeight(_heightCm);
    widget.data.smoking = _smoking;
    widget.data.drinking = _drinking;
    widget.data.workout = _fitnessLevel;
    widget.data.bio = _bioCtrl.text.trim();
    widget.data.photos = List<String>.from(_localPhotos);
    if (_localPhotos.isNotEmpty) {
      widget.data.profilePicture = _localPhotos.first;
    }
    widget.onNext();
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
            'About You & Profile Photos',
            style: TextStyle(
              color: OnboardingColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Career, lifestyle attributes & profile photos.',
            style: TextStyle(
              color: OnboardingColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          // Profession & Education
          UnderlineTextField(
            label: 'Profession / Occupation',
            hint: 'Software Engineer, Doctor, Entrepreneur',
            controller: _professionCtrl,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),

          const Text(
            'Education Level',
            style: TextStyle(color: OnboardingColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _educationLevels.map((edu) {
              final isSelected = _educationLevel == edu;
              return GoldChip(
                label: edu,
                selected: isSelected,
                onTap: () => setState(() => _educationLevel = edu),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Height Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Height',
                style: TextStyle(color: OnboardingColors.textSecondary, fontSize: 13),
              ),
              Text(
                _formatHeight(_heightCm),
                style: const TextStyle(
                  color: OnboardingColors.primaryGold,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: OnboardingColors.primaryGold,
              inactiveTrackColor: Colors.white12,
              thumbColor: OnboardingColors.primaryGold,
              overlayColor: OnboardingColors.primaryGold.withOpacity(0.2),
            ),
            child: Slider(
              value: _heightCm,
              min: 140,
              max: 220,
              divisions: 80,
              onChanged: (val) => setState(() => _heightCm = val),
            ),
          ),
          const SizedBox(height: 20),

          // Lifestyle Essentials (Smoking, Drinking, Fitness)
          const Text(
            'Smoking Habits',
            style: TextStyle(color: OnboardingColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _smokingOptions.map((opt) {
              final selected = _smoking == opt;
              return GoldChip(
                label: opt,
                selected: selected,
                onTap: () => setState(() => _smoking = opt),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          const Text(
            'Drinking Habits',
            style: TextStyle(color: OnboardingColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _drinkingOptions.map((opt) {
              final selected = _drinking == opt;
              return GoldChip(
                label: opt,
                selected: selected,
                onTap: () => setState(() => _drinking = opt),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          const Text(
            'Fitness Level',
            style: TextStyle(color: OnboardingColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _fitnessOptions.map((opt) {
              final selected = _fitnessLevel == opt;
              return GoldChip(
                label: opt,
                selected: selected,
                onTap: () => setState(() => _fitnessLevel = opt),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Short Bio Intro
          UnderlineTextField(
            label: 'Short Personal Bio',
            hint: 'Share a brief introduction about your goals, values and passions...',
            controller: _bioCtrl,
            maxLines: 3,
          ),
          const SizedBox(height: 28),

          // Profile Photos Grid (Required min 3 photos)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Profile Photos',
                style: TextStyle(
                  color: OnboardingColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${_localPhotos.length}/6 (Optional)',
                style: const TextStyle(
                  color: OnboardingColors.primaryGold,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.8,
            ),
            itemBuilder: (context, index) {
              final hasPhoto = index < _localPhotos.length;
              final photoPath = hasPhoto ? _localPhotos[index] : null;

              return GestureDetector(
                onTap: () => _pickPhoto(index),
                child: Container(
                  decoration: BoxDecoration(
                    color: OnboardingColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: hasPhoto
                          ? OnboardingColors.primaryGold
                          : OnboardingColors.unselectedBorder,
                      width: hasPhoto ? 2 : 1,
                    ),
                    image: photoPath != null
                        ? DecorationImage(
                            image: photoPath.startsWith('http')
                                ? NetworkImage(photoPath) as ImageProvider
                                : FileImage(File(photoPath)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: Stack(
                    children: [
                      if (!hasPhoto)
                        const Center(
                          child: Icon(
                            Icons.add_a_photo_rounded,
                            color: Colors.white38,
                            size: 28,
                          ),
                        ),
                      if (hasPhoto)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removePhoto(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 36),

          NextButton(
            label: 'Continue',
            enabled: _isValid,
            onPressed: _saveAndNext,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
