import 'package:flutter/material.dart';
import '../../../../models/onboarding_data.dart';
import '../../../../shared/widgets/onboarding_widgets.dart';

class OnboardingStep6Preferences extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingStep6Preferences({super.key, required this.data, required this.onNext, required this.onBack});

  @override
  State<OnboardingStep6Preferences> createState() => _OnboardingStep6PreferencesState();
}

class _OnboardingStep6PreferencesState extends State<OnboardingStep6Preferences> {
  late double _minAge;
  late double _maxAge;
  late TextEditingController _locationCtrl;
  String? _preferredEducation;
  late TextEditingController _preferredProfessionCtrl;
  late List<String> _preferredLifestyle;
  String? _preferredReligion;

  final List<String> _educationOptions = [
    'Any', 'High School', 'Bachelor\'s Degree', 'Master\'s Degree',
    'Doctorate / PhD', 'Professional Degree',
  ];

  final List<String> _religionOptions = [
    'Any', 'Same as mine', 'Christianity', 'Islam', 'Hinduism', 'Buddhism',
    'Judaism', 'Sikhism', 'Spiritual', 'Open to all',
  ];

  final List<Map<String, dynamic>> _lifestyleOptions = [
    {'label': 'Travel-oriented', 'icon': Icons.flight},
    {'label': 'Health-focused', 'icon': Icons.fitness_center},
    {'label': 'Family-oriented', 'icon': Icons.family_restroom},
    {'label': 'Career-driven', 'icon': Icons.trending_up},
    {'label': 'Social butterfly', 'icon': Icons.groups},
    {'label': 'Homebody', 'icon': Icons.home},
    {'label': 'Luxury lifestyle', 'icon': Icons.diamond},
    {'label': 'Minimalist', 'icon': Icons.eco},
  ];

  @override
  void initState() {
    super.initState();
    _minAge = widget.data.minAgePreference.toDouble();
    _maxAge = widget.data.maxAgePreference.toDouble();
    _locationCtrl = TextEditingController(text: widget.data.preferredLocation);
    _preferredEducation = widget.data.preferredEducation.isNotEmpty ? widget.data.preferredEducation : null;
    _preferredProfessionCtrl = TextEditingController(text: widget.data.preferredProfession);
    _preferredLifestyle = List.from(widget.data.preferredLifestyle);
    _preferredReligion = widget.data.preferredReligion.isNotEmpty ? widget.data.preferredReligion : null;
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _preferredProfessionCtrl.dispose();
    super.dispose();
  }

  void _toggleLifestyle(String tag) {
    setState(() {
      if (_preferredLifestyle.contains(tag)) {
        _preferredLifestyle.remove(tag);
      } else {
        _preferredLifestyle.add(tag);
      }
    });
  }

  void _handleNext() {
    if (_minAge >= _maxAge) {
      _showError('Minimum age must be less than maximum age');
      return;
    }

    widget.data.minAgePreference = _minAge.round();
    widget.data.maxAgePreference = _maxAge.round();
    widget.data.preferredLocation = _locationCtrl.text.trim();
    widget.data.preferredEducation = _preferredEducation ?? '';
    widget.data.preferredProfession = _preferredProfessionCtrl.text.trim();
    widget.data.preferredLifestyle = _preferredLifestyle;
    widget.data.preferredReligion = _preferredReligion ?? '';

    widget.onNext();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text('Partner Preferences', style: TextStyle(color: Colors.white, fontSize: 26, fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Describe your ideal match', style: TextStyle(color: Colors.white54, fontSize: 15)),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Age Range
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: OnboardingColors.fieldBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('AGE RANGE', style: TextStyle(color: OnboardingColors.primaryGold, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: OnboardingColors.primaryGold.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_minAge.round()} – ${_maxAge.round()}',
                                style: const TextStyle(color: OnboardingColors.primaryGold, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: OnboardingColors.primaryGold,
                            inactiveTrackColor: Colors.white12,
                            thumbColor: OnboardingColors.primaryGold,
                            overlayColor: OnboardingColors.primaryGold.withOpacity(0.2),
                            trackHeight: 4,
                          ),
                          child: RangeSlider(
                            values: RangeValues(_minAge, _maxAge),
                            min: 18,
                            max: 70,
                            divisions: 52,
                            onChanged: (v) => setState(() {
                              _minAge = v.start;
                              _maxAge = v.end;
                            }),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${_minAge.round()}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                            Text('${_maxAge.round()}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  PremiumTextField(label: 'PREFERRED LOCATION', hint: 'e.g., Same city, Anywhere', controller: _locationCtrl),
                  const SizedBox(height: 14),

                  PremiumDropdown(
                    label: 'MINIMUM EDUCATION',
                    hint: 'Select education preference',
                    value: _preferredEducation,
                    items: _educationOptions,
                    onChanged: (v) => setState(() => _preferredEducation = v),
                  ),
                  const SizedBox(height: 14),

                  PremiumTextField(label: 'PREFERRED PROFESSION', hint: 'e.g., Professional, Entrepreneur, Any', controller: _preferredProfessionCtrl),
                  const SizedBox(height: 14),

                  PremiumDropdown(
                    label: 'RELIGIOUS PREFERENCE',
                    hint: 'Select preference',
                    value: _preferredReligion,
                    items: _religionOptions,
                    onChanged: (v) => setState(() => _preferredReligion = v),
                  ),
                  const SizedBox(height: 22),

                  const SectionTitle(title: 'Partner Lifestyle', subtitle: 'What lifestyle traits do you prefer?'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _lifestyleOptions.map((opt) => GoldChip(
                      label: opt['label'],
                      icon: opt['icon'],
                      selected: _preferredLifestyle.contains(opt['label']),
                      onTap: () => _toggleLifestyle(opt['label']),
                      showCheckmark: true,
                    )).toList(),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          NextButton(label: 'Next', onPressed: _handleNext),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
