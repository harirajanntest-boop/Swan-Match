import 'package:flutter/material.dart';
import '../../../../models/onboarding_data.dart';
import '../../../../shared/widgets/onboarding_widgets.dart';

/// Consolidated step replacing the old separate `OnboardingStep3Intent` +
/// `OnboardingStep6Preferences`. Per the simplified onboarding spec, this
/// collects only:
///  - Dating intention (`lookingFor` — Marriage / Long-Term Relationship)
///  - Basic dating preferences: age-range slider + gender preference
///
/// Everything else that used to live in step 3 (marriageTimeline,
/// relocatePreference) and step 6 (religion-preference mode, priority
/// ranking, dealbreakers) is dropped from required onboarding — those remain
/// editable later from the Profile tab's optional "Edit preferences" screen.
class OnboardingStepIntentPreferences extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingStepIntentPreferences({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<OnboardingStepIntentPreferences> createState() =>
      _OnboardingStepIntentPreferencesState();
}

class _OnboardingStepIntentPreferencesState
    extends State<OnboardingStepIntentPreferences> {
  String _lookingFor = 'Marriage';
  RangeValues _ageRange = const RangeValues(21, 35);
  String _genderPreference = 'Everyone';

  final List<Map<String, String>> _goalOptions = [
    {
      'title': 'Marriage',
      'subtitle': 'Ready for lifelong commitment & partner search.',
      'icon': 'favorite',
    },
    {
      'title': 'Long-Term Relationship',
      'subtitle': 'Seeking serious long-term relationship leading to marriage.',
      'icon': 'handshake',
    },
  ];

  // Stored value is lowercased/trimmed by downstream matching (see
  // `partnerPreference` consumers in match_service.dart) — 'Men'/'Women'/'Both'
  // reuses that existing exact-match convention.
  final List<Map<String, String>> _genderOptions = [
    {'label': 'Men', 'value': 'Men'},
    {'label': 'Women', 'value': 'Women'},
    {'label': 'Everyone', 'value': 'Both'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.data.lookingFor.isNotEmpty) {
      _lookingFor = widget.data.lookingFor;
    }

    _ageRange = RangeValues(
      widget.data.minAgePreference.toDouble().clamp(18.0, 99.0),
      widget.data.maxAgePreference.toDouble().clamp(18.0, 99.0),
    );
    if (_ageRange.start >= _ageRange.end) {
      _ageRange = const RangeValues(21, 35);
    }

    final savedPref = widget.data.partnerPreference.trim();
    if (savedPref.isNotEmpty) {
      final match = _genderOptions.firstWhere(
        (opt) => opt['value']!.toLowerCase() == savedPref.toLowerCase(),
        orElse: () => _genderOptions.last,
      );
      _genderPreference = match['label']!;
    }
  }

  String get _genderPreferenceValue => _genderOptions
      .firstWhere((opt) => opt['label'] == _genderPreference)['value']!;

  void _saveAndNext() {
    widget.data.lookingFor = _lookingFor;
    widget.data.datingIntention = _lookingFor;
    widget.data.minAgePreference = _ageRange.start.toInt();
    widget.data.maxAgePreference = _ageRange.end.toInt();
    widget.data.partnerPreference = _genderPreferenceValue;
    widget.data.datingPreferences = {
      'minAge': widget.data.minAgePreference,
      'maxAge': widget.data.maxAgePreference,
      'genderPreference': _genderPreferenceValue,
    };
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
            'Intent & Preferences',
            style: TextStyle(
              color: OnboardingColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tell us what you\'re looking for and who you\'d like to meet.',
            style: TextStyle(
              color: OnboardingColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          // ── Dating Intention ─────────────────────────────────────────────
          const Text(
            'What are you looking for?',
            style: TextStyle(
              color: OnboardingColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ..._goalOptions.map((opt) {
            final isSelected = _lookingFor == opt['title'];
            return GestureDetector(
              onTap: () => setState(() => _lookingFor = opt['title']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? OnboardingColors.primaryGold.withOpacity(0.12)
                      : OnboardingColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? OnboardingColors.primaryGold
                        : Colors.white.withOpacity(0.08),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      opt['icon'] == 'favorite'
                          ? Icons.favorite_rounded
                          : Icons.handshake_rounded,
                      color: isSelected
                          ? OnboardingColors.primaryGold
                          : Colors.white54,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt['title']!,
                            style: TextStyle(
                              color: isSelected
                                  ? OnboardingColors.primaryGold
                                  : OnboardingColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            opt['subtitle']!,
                            style: const TextStyle(
                              color: OnboardingColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: OnboardingColors.primaryGold,
                        size: 22,
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 28),

          // ── Preferred Age Range ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Preferred Age Range',
                style: TextStyle(
                  color: OnboardingColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${_ageRange.start.toInt()} – ${_ageRange.end.toInt()} yrs',
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
            child: RangeSlider(
              values: _ageRange,
              min: 18,
              max: 70,
              divisions: 52,
              onChanged: (val) => setState(() => _ageRange = val),
            ),
          ),
          const SizedBox(height: 24),

          // ── Gender Preference ────────────────────────────────────────────
          const Text(
            'Show me',
            style: TextStyle(
              color: OnboardingColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: _genderOptions.map((opt) {
              final isSelected = _genderPreference == opt['label'];
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _genderPreference = opt['label']!),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? OnboardingColors.primaryGold.withOpacity(0.15)
                          : OnboardingColors.fieldBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? OnboardingColors.primaryGold
                            : Colors.white.withOpacity(0.08),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        opt['label']!,
                        style: TextStyle(
                          color: isSelected
                              ? OnboardingColors.primaryGold
                              : OnboardingColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
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
