import 'package:flutter/material.dart';
import '../../../../models/onboarding_data.dart';
import '../../../../shared/widgets/onboarding_widgets.dart';

class OnboardingStep5Values extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingStep5Values({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<OnboardingStep5Values> createState() => _OnboardingStep5ValuesState();
}

class _OnboardingStep5ValuesState extends State<OnboardingStep5Values> {
  int _familyImportance = 5; // 1 to 5
  String _childrenPreference = 'Yes';
  String _preferredFamilySize = 'Medium';
  String _financialStyle = 'Balanced';
  String _decisionMakingStyle = 'Balanced';

  final List<String> _childrenOptions = ['Yes', 'No', 'Undecided'];
  final List<String> _familySizeOptions = ['Small', 'Medium', 'Large'];
  final List<String> _financialStyleOptions = ['Saver', 'Balanced', 'Spender'];

  final List<Map<String, String>> _decisionStyleOptions = [
    {
      'title': 'Logical',
      'subtitle': 'Analytic, data-backed and structured decisions.',
    },
    {
      'title': 'Emotional',
      'subtitle': 'Intuitive, empathy-driven and heart-centered decisions.',
    },
    {
      'title': 'Balanced',
      'subtitle': 'Harmonizes logic, feelings, and consensus.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _familyImportance = widget.data.familyValuesImportance;
    if (widget.data.childrenPreference.isNotEmpty) {
      _childrenPreference = widget.data.childrenPreference;
    }
    if (widget.data.preferredFamilySize.isNotEmpty) {
      _preferredFamilySize = widget.data.preferredFamilySize;
    }
    if (widget.data.financialStyle.isNotEmpty) {
      _financialStyle = widget.data.financialStyle;
    }
    if (widget.data.decisionMakingStyle.isNotEmpty) {
      _decisionMakingStyle = widget.data.decisionMakingStyle;
    }
  }

  void _saveAndNext() {
    widget.data.familyValuesImportance = _familyImportance;
    widget.data.childrenPreference = _childrenPreference;
    widget.data.preferredFamilySize = _preferredFamilySize;
    widget.data.financialStyle = _financialStyle;
    widget.data.decisionMakingStyle = _decisionMakingStyle;
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
            'Family & Life Values',
            style: TextStyle(
              color: OnboardingColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Assess deep compatibility in family & decision making.',
            style: TextStyle(
              color: OnboardingColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          // Question 1: How important is family in your life? (1-5 Slider)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Importance of Family',
                style: TextStyle(
                  color: OnboardingColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$_familyImportance / 5',
                style: const TextStyle(
                  color: OnboardingColors.primaryGold,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: OnboardingColors.primaryGold,
              inactiveTrackColor: Colors.white12,
              thumbColor: OnboardingColors.primaryGold,
              overlayColor: OnboardingColors.primaryGold.withOpacity(0.2),
            ),
            child: Slider(
              value: _familyImportance.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              onChanged: (val) => setState(() => _familyImportance = val.toInt()),
            ),
          ),
          const SizedBox(height: 24),

          // Question 2: Would you like children?
          const Text(
            'Would you like children?',
            style: TextStyle(
              color: OnboardingColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: _childrenOptions.map((opt) {
              final isSelected = _childrenPreference == opt;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _childrenPreference = opt),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? OnboardingColors.primaryGold.withOpacity(0.15)
                          : OnboardingColors.cardBackground,
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
          const SizedBox(height: 24),

          // Question 3: Preferred Family Size
          const Text(
            'Preferred Family Size',
            style: TextStyle(
              color: OnboardingColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: _familySizeOptions.map((opt) {
              final isSelected = _preferredFamilySize == opt;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _preferredFamilySize = opt),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? OnboardingColors.primaryGold.withOpacity(0.15)
                          : OnboardingColors.cardBackground,
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
          const SizedBox(height: 24),

          // Question 4: Financial Style
          const Text(
            'Financial Management Style',
            style: TextStyle(
              color: OnboardingColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: _financialStyleOptions.map((opt) {
              final isSelected = _financialStyle == opt;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _financialStyle = opt),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? OnboardingColors.primaryGold.withOpacity(0.15)
                          : OnboardingColors.cardBackground,
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
          const SizedBox(height: 24),

          // Question 5: Decision Making Style
          const Text(
            'Decision Making Style',
            style: TextStyle(
              color: OnboardingColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ..._decisionStyleOptions.map((opt) {
            final isSelected = _decisionMakingStyle == opt['title'];
            return GestureDetector(
              onTap: () => setState(() => _decisionMakingStyle = opt['title']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? OnboardingColors.primaryGold.withOpacity(0.12)
                      : OnboardingColors.cardBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? OnboardingColors.primaryGold
                        : Colors.white.withOpacity(0.08),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
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
