import 'package:flutter/material.dart';
import '../../../../models/onboarding_data.dart';
import '../../../../shared/widgets/onboarding_widgets.dart';

class OnboardingStep4Cultural extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingStep4Cultural({super.key, required this.data, required this.onNext, required this.onBack});

  @override
  State<OnboardingStep4Cultural> createState() => _OnboardingStep4CulturalState();
}

class _OnboardingStep4CulturalState extends State<OnboardingStep4Cultural> {
  String? _religion;
  String? _spiritualLevel;
  String? _primaryLanguage;
  late TextEditingController _ethnicityCtrl;
  late List<String> _otherLanguages;
  late Map<String, String> _languageFluency;
  late double _familyValues;

  final List<String> _religionOptions = [
    'Christianity', 'Islam', 'Hinduism', 'Buddhism', 'Judaism',
    'Sikhism', 'Spiritual but not religious', 'Agnostic', 'Atheist', 'Other',
  ];

  final List<String> _spiritualOptions = [
    'Not Religious', 'Somewhat Spiritual', 'Very Spiritual', 'Deeply Devoted',
  ];

  final List<String> _languageOptions = [
    'English', 'Spanish', 'French', 'Arabic', 'Hindi', 'Mandarin',
    'Portuguese', 'Bengali', 'Russian', 'Japanese', 'Korean',
    'German', 'Italian', 'Tamil', 'Telugu', 'Turkish', 'Urdu', 'Other',
  ];

  final List<String> _fluencyLevels = ['Basic', 'Conversational', 'Fluent', 'Native'];

  final List<String> _familyValueLabels = ['Not important', 'Slightly', 'Moderate', 'Important', 'Very Important'];

  @override
  void initState() {
    super.initState();
    _religion = widget.data.religion.isNotEmpty ? widget.data.religion : null;
    _spiritualLevel = widget.data.spiritualLevel.isNotEmpty ? widget.data.spiritualLevel : null;
    _primaryLanguage = widget.data.primaryLanguage.isNotEmpty ? widget.data.primaryLanguage : null;
    _ethnicityCtrl = TextEditingController(text: widget.data.ethnicity);
    _otherLanguages = List.from(widget.data.otherLanguages);
    _languageFluency = Map.from(widget.data.languageFluency);
    _familyValues = widget.data.familyValuesImportance.toDouble();
  }

  @override
  void dispose() {
    _ethnicityCtrl.dispose();
    super.dispose();
  }

  void _toggleLanguage(String lang) {
    setState(() {
      if (_otherLanguages.contains(lang)) {
        _otherLanguages.remove(lang);
        _languageFluency.remove(lang);
      } else {
        _otherLanguages.add(lang);
        _languageFluency[lang] = 'Conversational';
      }
    });
  }

  void _handleNext() {
    if (_religion == null) {
      _showError('Please select your religion');
      return;
    }
    if (_primaryLanguage == null) {
      _showError('Please select your primary language');
      return;
    }

    widget.data.religion = _religion!;
    widget.data.spiritualLevel = _spiritualLevel ?? '';
    widget.data.ethnicity = _ethnicityCtrl.text.trim();
    widget.data.primaryLanguage = _primaryLanguage!;
    widget.data.otherLanguages = _otherLanguages;
    widget.data.languageFluency = _languageFluency;
    widget.data.familyValuesImportance = _familyValues.round();

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
          const Text('Cultural & Language', style: TextStyle(color: Colors.white, fontSize: 26, fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Your cultural background', style: TextStyle(color: Colors.white54, fontSize: 15)),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PremiumDropdown(
                    label: 'RELIGION',
                    hint: 'Select religion',
                    value: _religion,
                    items: _religionOptions,
                    onChanged: (v) => setState(() => _religion = v),
                  ),
                  const SizedBox(height: 14),

                  const SectionTitle(title: 'Spiritual Level'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10, runSpacing: 10,
                    children: _spiritualOptions.map((s) => GoldChip(
                      label: s,
                      selected: _spiritualLevel == s,
                      onTap: () => setState(() => _spiritualLevel = s),
                    )).toList(),
                  ),
                  const SizedBox(height: 18),

                  PremiumTextField(label: 'ETHNICITY / BACKGROUND', hint: 'e.g., South Asian, Caucasian', controller: _ethnicityCtrl),
                  const SizedBox(height: 18),

                  PremiumDropdown(
                    label: 'PRIMARY LANGUAGE',
                    hint: 'Select your primary language',
                    value: _primaryLanguage,
                    items: _languageOptions,
                    onChanged: (v) => setState(() => _primaryLanguage = v),
                  ),
                  const SizedBox(height: 18),

                  const SectionTitle(title: 'Other Languages', subtitle: 'Select any additional languages'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _languageOptions
                        .where((l) => l != _primaryLanguage)
                        .map((lang) => GoldChip(
                              label: lang,
                              selected: _otherLanguages.contains(lang),
                              onTap: () => _toggleLanguage(lang),
                              showCheckmark: true,
                            ))
                        .toList(),
                  ),

                  // Fluency levels for selected languages
                  if (_otherLanguages.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const SectionTitle(title: 'Fluency Levels'),
                    const SizedBox(height: 10),
                    ..._otherLanguages.map((lang) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PremiumDropdown(
                        label: lang.toUpperCase(),
                        hint: 'Select fluency',
                        value: _languageFluency[lang],
                        items: _fluencyLevels,
                        onChanged: (v) => setState(() => _languageFluency[lang] = v ?? 'Conversational'),
                      ),
                    )),
                  ],

                  const SizedBox(height: 18),

                  PremiumLabeledSlider(
                    label: 'Family Values Importance',
                    value: _familyValues,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    labelBuilder: (v) => _familyValueLabels[v.round() - 1],
                    onChanged: (v) => setState(() => _familyValues = v),
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
