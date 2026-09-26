import 'package:flutter/material.dart';
import '../../../../models/onboarding_data.dart';
import '../../../../shared/widgets/onboarding_widgets.dart';
import '../../../../shared/widgets/non_negotiables_section.dart';

class OnboardingStep6Preferences extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingStep6Preferences({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<OnboardingStep6Preferences> createState() =>
      _OnboardingStep6PreferencesState();
}

class _OnboardingStep6PreferencesState extends State<OnboardingStep6Preferences> {
  RangeValues _ageRange = const RangeValues(21, 35);

  // Religion preference: 'No Preference', 'Same Religion', 'Specific Religion'
  String _religionMode = 'No Preference';
  String _specificReligion = 'Hindu';
  List<String> _dealbreakers = [];

  List<String> _priorities = [
    'Family Values',
    'Communication',
    'Lifestyle Alignment',
    'Career Ambition',
    'Financial Maturity',
  ];

  final List<String> _religions = [
    'Hindu',
    'Muslim',
    'Christian',
    'Sikh',
    'Buddhist',
    'Jain',
    'Spiritual',
    'Other',
  ];

  // The user's own religion from Step 2 (may be empty)
  String get _userReligion => widget.data.religion.trim();
  bool get _userHasReligion => _userReligion.isNotEmpty;

  @override
  void initState() {
    super.initState();

    _ageRange = RangeValues(
      widget.data.minAgePreference.toDouble().clamp(18.0, 99.0),
      widget.data.maxAgePreference.toDouble().clamp(18.0, 99.0),
    );
    if (_ageRange.start >= _ageRange.end) {
      _ageRange = const RangeValues(21, 35);
    }

    // Restore saved religion mode — but guard against 'Same Religion' when
    // the user has no religion set in Step 2 (fallback to No Preference).
    final savedMode = widget.data.religionPreferenceMode;
    if (savedMode == 'Same Religion' && !_userHasReligion) {
      _religionMode = 'No Preference';
    } else if (savedMode.isNotEmpty) {
      _religionMode = savedMode;
    }

    if (widget.data.specificReligion.isNotEmpty) {
      _specificReligion = widget.data.specificReligion;
    }
    if (widget.data.rankedPartnerPriorities.isNotEmpty) {
      _priorities = List<String>.from(widget.data.rankedPartnerPriorities);
    }
    _dealbreakers = List<String>.from(widget.data.dealbreakers);
  }

  void _onReligionModeTap(String mode) {
    // Disable 'Same Religion' if user hasn't set their own religion
    if (mode == 'Same Religion' && !_userHasReligion) return;
    setState(() => _religionMode = mode);
  }

  void _saveAndNext() {
    widget.data.minAgePreference = _ageRange.start.toInt();
    widget.data.maxAgePreference = _ageRange.end.toInt();
    widget.data.religionPreferenceMode = _religionMode;

    switch (_religionMode) {
      case 'Same Religion':
        // Use the user's own religion from Step 2 as their preference
        widget.data.preferredReligion = _userReligion;
        widget.data.specificReligion = '';
        break;
      case 'Specific Religion':
        widget.data.preferredReligion = _specificReligion;
        widget.data.specificReligion = _specificReligion;
        break;
      default: // 'No Preference'
        widget.data.preferredReligion = 'Any';
        widget.data.specificReligion = '';
    }

    widget.data.rankedPartnerPriorities = List<String>.from(_priorities);
    widget.data.dealbreakers = List<String>.from(_dealbreakers);
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
            'Partner Preferences & Priorities',
            style: TextStyle(
              color: OnboardingColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Rank what matters most to calibrate your AI matches.',
            style: TextStyle(
              color: OnboardingColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          // ── Preferred Age Range ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Preferred Age Range',
                style: TextStyle(
                  color: OnboardingColors.textPrimary,
                  fontSize: 15,
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

          // ── Religion Preference ──────────────────────────────────────────
          Row(
            children: [
              const Text(
                'Religion Preference',
                style: TextStyle(
                  color: OnboardingColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!_userHasReligion) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Open to All',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // Contextual hint when user has no religion
          if (!_userHasReligion)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'You didn\'t select a religion in Basic Details — "Same Religion" is not available. Add your religion there to enable it.',
                style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
              ),
            )
          else
            const SizedBox(height: 4),

          // Three mode buttons
          Row(
            children: ['No Preference', 'Same Religion', 'Specific Religion'].map((mode) {
              final isSelected = _religionMode == mode;
              final isDisabled = mode == 'Same Religion' && !_userHasReligion;

              return Expanded(
                child: GestureDetector(
                  onTap: isDisabled ? null : () => _onReligionModeTap(mode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isDisabled
                          ? Colors.white.withOpacity(0.03)
                          : isSelected
                              ? OnboardingColors.primaryGold.withOpacity(0.15)
                              : OnboardingColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDisabled
                            ? Colors.white.withOpacity(0.05)
                            : isSelected
                                ? OnboardingColors.primaryGold
                                : Colors.white.withOpacity(0.08),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        mode,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDisabled
                              ? Colors.white24
                              : isSelected
                                  ? OnboardingColors.primaryGold
                                  : OnboardingColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // Contextual detail panel — animates in based on selected mode
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _buildReligionDetail(),
          ),

          const SizedBox(height: 28),

          // ── Priority Ranking ─────────────────────────────────────────────
          Row(
            children: const [
              Icon(Icons.format_list_numbered_rounded, color: OnboardingColors.primaryGold, size: 20),
              SizedBox(width: 8),
              Text(
                'Rank Your Top Partner Priorities',
                style: TextStyle(
                  color: OnboardingColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Reorder items to prioritize what matters most to your compatibility engine.',
            style: TextStyle(color: OnboardingColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),

          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _priorities.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _priorities.removeAt(oldIndex);
                _priorities.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final priorityItem = _priorities[index];
              return Container(
                key: ValueKey(priorityItem),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: OnboardingColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: OnboardingColors.primaryGold,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        priorityItem,
                        style: const TextStyle(
                          color: OnboardingColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.drag_handle_rounded,
                      color: Colors.white38,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 36),

          NonNegotiablesSection(
            selected: _dealbreakers,
            onChanged: (v) => setState(() => _dealbreakers = v),
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

  /// Returns the contextual detail panel for the selected religion mode.
  Widget _buildReligionDetail() {
    if (_religionMode == 'Same Religion') {
      // Confirmation card showing the user's own religion
      return Container(
        key: const ValueKey('same'),
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: OnboardingColors.primaryGold.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: OnboardingColors.primaryGold.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: OnboardingColors.primaryGold,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, height: 1.4),
                  children: [
                    const TextSpan(
                      text: 'Your match must be ',
                      style: TextStyle(color: Colors.white60),
                    ),
                    TextSpan(
                      text: _userReligion,
                      style: const TextStyle(
                        color: OnboardingColors.primaryGold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(
                      text: ' — based on your religion from Basic Details.',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_religionMode == 'Specific Religion') {
      // Let user pick any religion from the chip list
      return Column(
        key: const ValueKey('specific'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _religions.map((rel) {
              final selected = _specificReligion == rel;
              return GoldChip(
                label: rel,
                selected: selected,
                onTap: () => setState(() => _specificReligion = rel),
              );
            }).toList(),
          ),
        ],
      );
    }

    // 'No Preference' — no extra UI
    return const SizedBox(key: ValueKey('none'));
  }
}
