import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../models/onboarding_data.dart';
import '../../../../shared/widgets/onboarding_widgets.dart';

// SCREEN 6: Distance Preference
class DistancePreferenceScreen extends StatefulWidget {
  final OnboardingData data;
  final Function(int) onNext;

  const DistancePreferenceScreen({
    super.key,
    required this.data,
    required this.onNext,
  });

  @override
  State<DistancePreferenceScreen> createState() => _DistancePreferenceScreenState();
}

class _DistancePreferenceScreenState extends State<DistancePreferenceScreen> {
  double _distance = 50.0;

  @override
  void initState() {
    super.initState();
    _distance = widget.data.distanceKm.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardingColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.arrow_back,
                      color: OnboardingColors.textPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 40),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close,
                      color: OnboardingColors.skipButton,
                      size: 24,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Title
              const Text(
                "Your distance preference?",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: OnboardingColors.textPrimary,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Subtitle
              const Text(
                "Set the max distance for potential matches.",
                style: TextStyle(
                  fontSize: 16,
                  color: OnboardingColors.textSecondary,
                  height: 1.4,
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Distance Slider
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Distance Preference",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: OnboardingColors.textPrimary,
                        ),
                      ),
                      Text(
                        "${_distance.round()} km",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: OnboardingColors.primaryGold,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: OnboardingColors.primaryGold,
                      inactiveTrackColor: Colors.white.withOpacity(0.2),
                      thumbColor: OnboardingColors.primaryGold,
                      overlayColor: OnboardingColors.primaryGold.withOpacity(0.2),
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                    ),
                    child: Slider(
                      value: _distance,
                      min: 10,
                      max: 500,
                      divisions: 49,
                      onChanged: (value) {
                        setState(() {
                          _distance = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Note
              const Text(
                "You can change preferences later in Settings.",
                style: TextStyle(
                  fontSize: 14,
                  color: OnboardingColors.textSecondary,
                ),
              ),
              
              const Spacer(),
              
              // Next Button
              Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: NextButton(
                  label: "Next",
                  enabled: true,
                  onPressed: () => widget.onNext(_distance.round()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// SCREEN 7: What Are You Looking For?
class LookingForScreen extends StatefulWidget {
  final OnboardingData data;
  final Function(String) onNext;

  const LookingForScreen({
    super.key,
    required this.data,
    required this.onNext,
  });

  @override
  State<LookingForScreen> createState() => _LookingForScreenState();
}

class _LookingForScreenState extends State<LookingForScreen> {
  String _selectedOption = '';

  @override
  void initState() {
    super.initState();
    _selectedOption = widget.data.lookingFor;
  }

  final List<Map<String, String>> _options = [
    {'emoji': 'diamond', 'label': 'Ready to marry'},
    {'emoji': 'favorite', 'label': 'Long-term partner'},
    {'emoji': 'handshake', 'label': 'Something serious'},
    {'emoji': 'schedule', 'label': 'Still figuring it out'},
    {'emoji': 'visibility', 'label': 'Just browsing'},
    {'emoji': 'auto_awesome', 'label': 'Let love lead'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardingColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.arrow_back,
                      color: OnboardingColors.textPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 40),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close,
                      color: OnboardingColors.skipButton,
                      size: 24,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Title
              const Text(
                "What are you looking for?",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: OnboardingColors.textPrimary,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Subtitle
              const Text(
                "Be honest \u2014 it helps find the right match.",
                style: TextStyle(
                  fontSize: 16,
                  color: OnboardingColors.textSecondary,
                  height: 1.4,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Options Grid
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: _options.length,
                  itemBuilder: (context, index) {
                    final option = _options[index];
                    final isSelected = _selectedOption == option['label'];
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedOption = option['label']!;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? OnboardingColors.primaryGold.withOpacity(0.1)
                              : OnboardingColors.cardBackground,
                          border: Border.all(
                            color: isSelected 
                                ? OnboardingColors.selectedBorder
                                : OnboardingColors.unselectedBorder,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getIconData(option['emoji']!),
                              color: isSelected 
                                  ? OnboardingColors.primaryGold 
                                  : OnboardingColors.textPrimary,
                              size: 32,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              option['label']!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isSelected 
                                    ? OnboardingColors.primaryGold 
                                    : OnboardingColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Next Button
              Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: NextButton(
                  label: "Next",
                  enabled: _selectedOption.isNotEmpty,
                  onPressed: () => widget.onNext(_selectedOption),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconData(String emojiName) {
    switch (emojiName) {
      case 'diamond': return Icons.diamond_outlined;
      case 'favorite': return Icons.favorite_outline;
      case 'handshake': return Icons.handshake_outlined;
      case 'schedule': return Icons.schedule_outlined;
      case 'visibility': return Icons.visibility_outlined;
      case 'auto_awesome': return Icons.auto_awesome_outlined;
      default: return Icons.help_outline;
    }
  }
}

// SCREEN 8: Education & Profession
class EducationProfessionScreen extends StatefulWidget {
  final OnboardingData data;
  final Function(String, String, String) onNext;

  const EducationProfessionScreen({
    super.key,
    required this.data,
    required this.onNext,
  });

  @override
  State<EducationProfessionScreen> createState() => _EducationProfessionScreenState();
}

class _EducationProfessionScreenState extends State<EducationProfessionScreen> {
  final TextEditingController _qualificationController = TextEditingController();
  final TextEditingController _universityController = TextEditingController();
  final TextEditingController _professionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _qualificationController.text = widget.data.highestQualification;
    _universityController.text = widget.data.university;
    _professionController.text = widget.data.profession;
  }

  @override
  void dispose() {
    _qualificationController.dispose();
    _universityController.dispose();
    _professionController.dispose();
    super.dispose();
  }

  bool get _isNextEnabled => _qualificationController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardingColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.arrow_back,
                      color: OnboardingColors.textPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 40),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close,
                      color: OnboardingColors.skipButton,
                      size: 24,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Title
              const Text(
                "Your education & profession",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: OnboardingColors.textPrimary,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Qualification Field
              UnderlineTextField(
                controller: _qualificationController,
                hint: "Highest Qualification",
                onChanged: (_) => setState(() {}),
              ),
              
              const SizedBox(height: 24),
              
              // University Field
              UnderlineTextField(
                controller: _universityController,
                hint: "College / University",
              ),
              
              const SizedBox(height: 24),
              
              // Profession Field
              UnderlineTextField(
                controller: _professionController,
                hint: "Current Profession / Job",
              ),
              
              const SizedBox(height: 16),
              
              // Helper Text
              const Text(
                "This is how it'll appear on your profile.",
                style: TextStyle(
                  fontSize: 14,
                  color: OnboardingColors.textSecondary,
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Next Button
              Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: NextButton(
                  label: "Next",
                  enabled: _isNextEnabled,
                  onPressed: () => widget.onNext(
                    _qualificationController.text.trim(),
                    _universityController.text.trim(),
                    _professionController.text.trim(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// SCREEN 9: Lifestyle Habits
class LifestyleHabitsScreen extends StatefulWidget {
  final OnboardingData data;
  final Function(String, String, String, List<String>) onNext;

  const LifestyleHabitsScreen({
    super.key,
    required this.data,
    required this.onNext,
  });

  @override
  State<LifestyleHabitsScreen> createState() => _LifestyleHabitsScreenState();
}

class _LifestyleHabitsScreenState extends State<LifestyleHabitsScreen> {
  String _drinking = '';
  String _smoking = '';
  String _workout = '';
  List<String> _pets = [];

  @override
  void initState() {
    super.initState();
    _drinking = widget.data.drinking;
    _smoking = widget.data.smoking;
    _workout = widget.data.workout;
    _pets = List.from(widget.data.pets);
  }

  final List<String> _drinkingOptions = [
    "Non-drinker", "Sober", "Sober curious", "On special occasions", 
    "Socially on weekends", "Most nights"
  ];

  final List<String> _smokingOptions = [
    "Non-smoker", "Social smoker", "Smoker when drinking", 
    "Smoker", "Trying to quit"
  ];

  final List<String> _workoutOptions = [
    "Everyday", "Often", "Sometimes", "Never"
  ];

  final List<String> _petOptions = [
    "Dog", "Cat", "Bird", "Reptile", "Fish", "Hamster", "Rabbit",
    "Pet-free", "Want a pet", "All the pets", "Allergic to pets"
  ];

  int get _completedSections {
    int count = 0;
    if (_drinking.isNotEmpty) count++;
    if (_smoking.isNotEmpty) count++;
    if (_workout.isNotEmpty) count++;
    if (_pets.isNotEmpty) count++;
    return count;
  }

  bool get _isNextEnabled => _completedSections == 4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardingColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(
                          Icons.arrow_back,
                          color: OnboardingColors.textPrimary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 40),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(
                          Icons.close,
                          color: OnboardingColors.skipButton,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Title
                  Text(
                    "Let's talk lifestyle, ${widget.data.firstName}",
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: OnboardingColors.textPrimary,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Subtitle
                  const Text(
                    "Do their habits match yours? You go first.",
                    style: TextStyle(
                      fontSize: 16,
                      color: OnboardingColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Drinking Section
                    _SectionHeader("🍺", "How often do you drink?"),
                    _buildChipGrid(_drinkingOptions, _drinking, (value) {
                      setState(() => _drinking = value);
                    }),

                    SectionDivider(),

                    // Smoking Section
                    _SectionHeader("🚬", "How often do you smoke?"),
                    _buildChipGrid(_smokingOptions, _smoking, (value) {
                      setState(() => _smoking = value);
                    }),

                    SectionDivider(),

                    // Workout Section
                    _SectionHeader("🏋️", "Do you workout?"),
                    _buildChipGrid(_workoutOptions, _workout, (value) {
                      setState(() => _workout = value);
                    }),

                    SectionDivider(),

                    // Pets Section
                    _SectionHeader("🐾", "Do you have any pets?"),
                    _buildChipGrid(_petOptions, _pets, (value) {
                      setState(() {
                        if (_pets.contains(value)) {
                          _pets.remove(value);
                        } else {
                          _pets.add(value);
                        }
                      });
                    }),
                    
                    const SizedBox(height: 100), // Space for button
                  ],
                ),
              ),
            ),
            
            // Bottom Button
            Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: NextButton(
                label: "Next $_completedSections/4",
                enabled: _isNextEnabled,
                onPressed: () => widget.onNext(_drinking, _smoking, _workout, _pets),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _SectionHeader(String emoji, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipGrid(List<String> options, dynamic selected, Function(String) onTap) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map<Widget>((option) {
        final isSelected = selected is List ? selected.contains(option) : selected == option;
        return GoldChip(
          label: option,
          selected: isSelected,
          onTap: () => onTap(option),
        );
      }).toList(),
    );
  }
}
