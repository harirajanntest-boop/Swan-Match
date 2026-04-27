import 'package:flutter/material.dart';
import '../../../../models/onboarding_data.dart';
import '../../../../shared/widgets/onboarding_widgets.dart';

class OnboardingStep3Lifestyle extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingStep3Lifestyle({super.key, required this.data, required this.onNext, required this.onBack});

  @override
  State<OnboardingStep3Lifestyle> createState() => _OnboardingStep3LifestyleState();
}

class _OnboardingStep3LifestyleState extends State<OnboardingStep3Lifestyle> {
  String? _educationLevel;
  String? _industry;
  String? _incomeRange;
  String? _netWorthRange;
  late TextEditingController _professionCtrl;
  late List<String> _selectedLifestyleTags;

  final List<String> _educationOptions = [
    'High School', 'Associate Degree', 'Bachelor\'s Degree', 'Master\'s Degree',
    'Doctorate / PhD', 'Professional Degree (MD, JD)', 'Trade / Vocational', 'Self-educated',
  ];

  final List<String> _industryOptions = [
    'Technology', 'Finance / Banking', 'Healthcare', 'Law', 'Education',
    'Real Estate', 'Consulting', 'Arts & Entertainment', 'Government',
    'Engineering', 'Hospitality', 'Retail', 'Entrepreneurship', 'Other',
  ];

  final List<String> _incomeOptions = [
    'Under \$25K', '\$25K – \$50K', '\$50K – \$75K', '\$75K – \$100K',
    '\$100K – \$150K', '\$150K – \$250K', '\$250K – \$500K', '\$500K+',
    'Prefer not to say',
  ];

  final List<String> _netWorthOptions = [
    'Under \$100K', '\$100K – \$500K', '\$500K – \$1M', '\$1M – \$5M',
    '\$5M – \$10M', '\$10M+', 'Prefer not to say',
  ];

  final List<Map<String, dynamic>> _lifestyleOptions = [
    {'label': 'Travel', 'icon': Icons.flight},
    {'label': 'Fitness', 'icon': Icons.fitness_center},
    {'label': 'Luxury', 'icon': Icons.diamond},
    {'label': 'Private', 'icon': Icons.shield},
    {'label': 'Social', 'icon': Icons.groups},
    {'label': 'Outdoors', 'icon': Icons.terrain},
    {'label': 'Foodie', 'icon': Icons.restaurant},
    {'label': 'Wellness', 'icon': Icons.spa},
    {'label': 'Cultural', 'icon': Icons.museum},
    {'label': 'Minimalist', 'icon': Icons.eco},
  ];

  @override
  void initState() {
    super.initState();
    _educationLevel = widget.data.educationLevel.isNotEmpty ? widget.data.educationLevel : null;
    _industry = widget.data.industry.isNotEmpty ? widget.data.industry : null;
    _incomeRange = widget.data.incomeRange.isNotEmpty ? widget.data.incomeRange : null;
    _netWorthRange = widget.data.netWorthRange.isNotEmpty ? widget.data.netWorthRange : null;
    _professionCtrl = TextEditingController(text: widget.data.profession);
    _selectedLifestyleTags = List.from(widget.data.lifestyleTags);
  }

  @override
  void dispose() {
    _professionCtrl.dispose();
    super.dispose();
  }

  void _toggleLifestyleTag(String tag) {
    setState(() {
      if (_selectedLifestyleTags.contains(tag)) {
        _selectedLifestyleTags.remove(tag);
      } else {
        _selectedLifestyleTags.add(tag);
      }
    });
  }

  void _handleNext() {
    if (_educationLevel == null) {
      _showError('Please select your education level');
      return;
    }
    if (_professionCtrl.text.trim().isEmpty) {
      _showError('Please enter your profession');
      return;
    }
    if (_incomeRange == null) {
      _showError('Please select your income range');
      return;
    }

    widget.data.educationLevel = _educationLevel!;
    widget.data.profession = _professionCtrl.text.trim();
    widget.data.industry = _industry ?? '';
    widget.data.incomeRange = _incomeRange!;
    widget.data.netWorthRange = _netWorthRange ?? '';
    widget.data.lifestyleTags = _selectedLifestyleTags;

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
          const Text('Lifestyle & Career', style: TextStyle(color: Colors.white, fontSize: 26, fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Your professional background', style: TextStyle(color: Colors.white54, fontSize: 15)),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PremiumDropdown(
                    label: 'EDUCATION LEVEL',
                    hint: 'Select education',
                    value: _educationLevel,
                    items: _educationOptions,
                    onChanged: (v) => setState(() => _educationLevel = v),
                  ),
                  const SizedBox(height: 14),

                  PremiumTextField(label: 'PROFESSION', hint: 'e.g., Software Engineer', controller: _professionCtrl),
                  const SizedBox(height: 14),

                  PremiumDropdown(
                    label: 'INDUSTRY',
                    hint: 'Select industry',
                    value: _industry,
                    items: _industryOptions,
                    onChanged: (v) => setState(() => _industry = v),
                  ),
                  const SizedBox(height: 14),

                  PremiumDropdown(
                    label: 'ANNUAL INCOME',
                    hint: 'Select income range',
                    value: _incomeRange,
                    items: _incomeOptions,
                    onChanged: (v) => setState(() => _incomeRange = v),
                  ),
                  const SizedBox(height: 14),

                  PremiumDropdown(
                    label: 'NET WORTH (OPTIONAL)',
                    hint: 'Select net worth range',
                    value: _netWorthRange,
                    items: _netWorthOptions,
                    onChanged: (v) => setState(() => _netWorthRange = v),
                  ),
                  const SizedBox(height: 24),

                  const SectionTitle(title: 'Lifestyle', subtitle: 'Select tags that describe you'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10, runSpacing: 10,
                    children: _lifestyleOptions.map((opt) => GoldChip(
                      label: opt['label'],
                      icon: opt['icon'],
                      selected: _selectedLifestyleTags.contains(opt['label']),
                      onTap: () => _toggleLifestyleTag(opt['label']),
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
