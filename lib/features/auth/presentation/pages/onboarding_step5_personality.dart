import 'package:flutter/material.dart';
import '../../../../models/onboarding_data.dart';
import '../../../../shared/widgets/onboarding_widgets.dart';

class OnboardingStep5Personality extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingStep5Personality({super.key, required this.data, required this.onNext, required this.onBack});

  @override
  State<OnboardingStep5Personality> createState() => _OnboardingStep5PersonalityState();
}

class _OnboardingStep5PersonalityState extends State<OnboardingStep5Personality> {
  late TextEditingController _bioCtrl;
  late List<String> _selectedTraits;
  late List<String> _selectedInterests;
  String? _smoking;
  String? _drinking;

  final List<Map<String, dynamic>> _traitOptions = [
    {'label': 'Ambitious', 'icon': Icons.rocket_launch},
    {'label': 'Adventurous', 'icon': Icons.explore},
    {'label': 'Empathetic', 'icon': Icons.favorite},
    {'label': 'Humorous', 'icon': Icons.sentiment_very_satisfied},
    {'label': 'Creative', 'icon': Icons.palette},
    {'label': 'Intellectual', 'icon': Icons.school},
    {'label': 'Calm & Patient', 'icon': Icons.self_improvement},
    {'label': 'Confident', 'icon': Icons.star},
    {'label': 'Loyal', 'icon': Icons.handshake},
    {'label': 'Spontaneous', 'icon': Icons.bolt},
    {'label': 'Organised', 'icon': Icons.list_alt},
    {'label': 'Romantic', 'icon': Icons.favorite_border},
  ];

  final List<Map<String, dynamic>> _interestOptions = [
    {'label': 'Travel', 'icon': Icons.flight},
    {'label': 'Reading', 'icon': Icons.menu_book},
    {'label': 'Music', 'icon': Icons.music_note},
    {'label': 'Cooking', 'icon': Icons.restaurant},
    {'label': 'Photography', 'icon': Icons.camera_alt},
    {'label': 'Sports', 'icon': Icons.sports_soccer},
    {'label': 'Art', 'icon': Icons.brush},
    {'label': 'Technology', 'icon': Icons.computer},
    {'label': 'Movies', 'icon': Icons.movie},
    {'label': 'Yoga & Meditation', 'icon': Icons.spa},
    {'label': 'Dancing', 'icon': Icons.nightlife},
    {'label': 'Hiking', 'icon': Icons.terrain},
    {'label': 'Gaming', 'icon': Icons.sports_esports},
    {'label': 'Volunteering', 'icon': Icons.volunteer_activism},
    {'label': 'Fashion', 'icon': Icons.checkroom},
    {'label': 'Gardening', 'icon': Icons.local_florist},
    {'label': 'Writing', 'icon': Icons.edit},
    {'label': 'Fitness', 'icon': Icons.fitness_center},
  ];

  final List<String> _habitOptions = ['Never', 'Occasionally', 'Socially', 'Regularly', 'Prefer not to say'];

  @override
  void initState() {
    super.initState();
    _bioCtrl = TextEditingController(text: widget.data.bio);
    _selectedTraits = List.from(widget.data.personalityTraits);
    _selectedInterests = List.from(widget.data.interests);
    _smoking = widget.data.smoking.isNotEmpty ? widget.data.smoking : null;
    _drinking = widget.data.drinking.isNotEmpty ? widget.data.drinking : null;
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    super.dispose();
  }

  void _toggleItem(List<String> list, String item) {
    setState(() {
      if (list.contains(item)) {
        list.remove(item);
      } else {
        list.add(item);
      }
    });
  }

  int _wordCount(String text) => text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

  void _handleNext() {
    final bio = _bioCtrl.text.trim();
    if (bio.isEmpty || _wordCount(bio) < 10) {
      _showError('Please write a bio (at least 10 words)');
      return;
    }
    if (_wordCount(bio) > 300) {
      _showError('Bio must be under 300 words');
      return;
    }
    if (_selectedTraits.length < 2) {
      _showError('Please select at least 2 personality traits');
      return;
    }
    if (_selectedInterests.length < 3) {
      _showError('Please select at least 3 interests');
      return;
    }
    if (_smoking == null || _smoking!.isEmpty) {
      _showError('Please select your smoking habit');
      return;
    }
    if (_drinking == null || _drinking!.isEmpty) {
      _showError('Please select your drinking habit');
      return;
    }

    widget.data.bio = bio;
    widget.data.personalityTraits = _selectedTraits;
    widget.data.interests = _selectedInterests;
    widget.data.smoking = _smoking!;
    widget.data.drinking = _drinking!;

    widget.onNext();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wc = _wordCount(_bioCtrl.text);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text('Personality & Profile', style: TextStyle(color: Colors.white, fontSize: 26, fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Show who you really are', style: TextStyle(color: Colors.white54, fontSize: 15)),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bio
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
                            const Text('ABOUT YOU', style: TextStyle(color: OnboardingColors.primaryGold, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                            Text('$wc / 300 words', style: TextStyle(color: wc > 300 ? Colors.red : Colors.white38, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _bioCtrl,
                          maxLines: 5,
                          style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
                          decoration: const InputDecoration(
                            hintText: 'Tell your story — what makes you unique, your passions, and what you\'re looking for in a partner...',
                            hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Personality Traits
                  SectionTitle(title: 'Personality Traits', subtitle: 'Select at least 2 (${_selectedTraits.length} selected)'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _traitOptions.map((t) => GoldChip(
                      label: t['label'],
                      icon: t['icon'],
                      selected: _selectedTraits.contains(t['label']),
                      onTap: () => _toggleItem(_selectedTraits, t['label']),
                      showCheckmark: true,
                    )).toList(),
                  ),
                  const SizedBox(height: 22),

                  // Interests
                  SectionTitle(title: 'Interests & Hobbies', subtitle: 'Select at least 3 (${_selectedInterests.length} selected)'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _interestOptions.map((i) => GoldChip(
                      label: i['label'],
                      icon: i['icon'],
                      selected: _selectedInterests.contains(i['label']),
                      onTap: () => _toggleItem(_selectedInterests, i['label']),
                      showCheckmark: true,
                    )).toList(),
                  ),
                  const SizedBox(height: 22),

                  // Habits
                  PremiumDropdown(
                    label: 'SMOKING',
                    hint: 'Select habit',
                    value: _smoking,
                    items: _habitOptions,
                    onChanged: (v) => setState(() => _smoking = v),
                  ),
                  const SizedBox(height: 14),
                  PremiumDropdown(
                    label: 'DRINKING',
                    hint: 'Select habit',
                    value: _drinking,
                    items: _habitOptions,
                    onChanged: (v) => setState(() => _drinking = v),
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
