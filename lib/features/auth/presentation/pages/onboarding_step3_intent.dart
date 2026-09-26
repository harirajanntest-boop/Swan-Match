import 'package:flutter/material.dart';
import '../../../../models/onboarding_data.dart';
import '../../../../shared/widgets/onboarding_widgets.dart';

class OnboardingStep3Intent extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingStep3Intent({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<OnboardingStep3Intent> createState() => _OnboardingStep3IntentState();
}

class _OnboardingStep3IntentState extends State<OnboardingStep3Intent> {
  String _lookingFor = 'Marriage';
  String _marriageTimeline = '1–3 years';
  String _relocatePreference = 'Depends';

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

  final List<Map<String, String>> _timelineOptions = [
    {
      'title': 'Within 1 year',
      'subtitle': 'Active planning for marriage in the near term.',
    },
    {
      'title': '1–3 years',
      'subtitle': 'Building a relationship with marriage goal.',
    },
    {
      'title': 'Flexible',
      'subtitle': 'Open timeline based on partner alignment.',
    },
  ];

  final List<String> _relocateOptions = ['Yes', 'No', 'Depends'];

  @override
  void initState() {
    super.initState();
    if (widget.data.lookingFor.isNotEmpty) {
      _lookingFor = widget.data.lookingFor;
    }
    if (widget.data.marriageTimeline.isNotEmpty) {
      _marriageTimeline = widget.data.marriageTimeline;
    }
    if (widget.data.relocatePreference.isNotEmpty) {
      _relocatePreference = widget.data.relocatePreference;
    }
  }

  void _saveAndNext() {
    widget.data.lookingFor = _lookingFor;
    widget.data.marriageTimeline = _marriageTimeline;
    widget.data.relocatePreference = _relocatePreference;
    widget.data.willingToRelocate = _relocatePreference == 'Yes'
        ? true
        : _relocatePreference == 'No'
            ? false
            : null;
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
            'Relationship Goals',
            style: TextStyle(
              color: OnboardingColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Understand your commitment & marriage timeline.',
            style: TextStyle(
              color: OnboardingColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          // Question 1: What are you looking for?
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
          const SizedBox(height: 24),

          // Question 2: How soon are you planning for marriage?
          const Text(
            'How soon are you planning for marriage?',
            style: TextStyle(
              color: OnboardingColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ..._timelineOptions.map((opt) {
            final isSelected = _marriageTimeline == opt['title'];
            return GestureDetector(
              onTap: () => setState(() => _marriageTimeline = opt['title']!),
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
                    const Icon(
                      Icons.access_time_filled_rounded,
                      color: OnboardingColors.primaryGold,
                      size: 20,
                    ),
                    const SizedBox(width: 14),
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
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
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
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),

          // Question 3: Would you relocate after marriage?
          const Text(
            'Would you relocate after marriage?',
            style: TextStyle(
              color: OnboardingColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: _relocateOptions.map((opt) {
              final isSelected = _relocatePreference == opt;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _relocatePreference = opt),
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
                        opt,
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
