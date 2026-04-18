import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../models/onboarding_data.dart';
import '../../../../shared/widgets/onboarding_widgets.dart';

// SCREEN 10: Values & Identity
class ValuesIdentityScreen extends StatefulWidget {
  final OnboardingData data;
  final Function(String, String, String, String) onNext;

  const ValuesIdentityScreen({
    super.key,
    required this.data,
    required this.onNext,
  });

  @override
  State<ValuesIdentityScreen> createState() => _ValuesIdentityScreenState();
}

class _ValuesIdentityScreenState extends State<ValuesIdentityScreen> {
  String _communicationStyle = '';
  String _loveLanguage = '';
  String _educationLevel = '';
  String _zodiac = '';

  @override
  void initState() {
    super.initState();
    _communicationStyle = widget.data.communicationStyle;
    _loveLanguage = widget.data.loveLanguage;
    _educationLevel = widget.data.educationLevel;
    _zodiac = widget.data.zodiac;
  }

  final List<String> _communicationOptions = [
    "I stay on WhatsApp all day", "Big time texter", "Phone caller",
    "Video chatter", "I'm slow to answer", "Bad texter", "Better in person"
  ];

  final List<String> _loveLanguageOptions = [
    "Thoughtful gestures", "Presents", "Touch", 
    "Compliments", "Time together"
  ];

  final List<String> _educationOptions = [
    "High School", "Diploma", "Bachelors", "In College", 
    "Masters", "PhD", "In Grad School", "Trade School"
  ];

  final List<String> _zodiacOptions = [
    "Capricorn", "Aquarius", "Pisces", "Aries", "Taurus", "Gemini",
    "Cancer", "Leo", "Virgo", "Libra", "Scorpio", "Sagittarius"
  ];

  int get _completedSections {
    int count = 0;
    if (_communicationStyle.isNotEmpty) count++;
    if (_loveLanguage.isNotEmpty) count++;
    if (_educationLevel.isNotEmpty) count++;
    if (_zodiac.isNotEmpty) count++;
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
                  const Text(
                    "What else makes you \u2014 you?",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: OnboardingColors.textPrimary,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Subtitle
                  const Text(
                    "Don't hold back. Authenticity attracts authenticity.",
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
                    // Communication Style Section
                    _SectionHeader("💬", "What is your communication style?"),
                    _buildChipGrid(_communicationOptions, _communicationStyle, (value) {
                      setState(() => _communicationStyle = value);
                    }),

                    SectionDivider(),

                    // Love Language Section
                    _SectionHeader("💝", "How do you receive love?"),
                    _buildChipGrid(_loveLanguageOptions, _loveLanguage, (value) {
                      setState(() => _loveLanguage = value);
                    }),

                    SectionDivider(),

                    // Education Level Section
                    _SectionHeader("🎓", "What is your education level?"),
                    _buildChipGrid(_educationOptions, _educationLevel, (value) {
                      setState(() => _educationLevel = value);
                    }),

                    SectionDivider(),

                    // Zodiac Section
                    _SectionHeader("♑", "What is your zodiac sign?"),
                    _buildChipGrid(_zodiacOptions, _zodiac, (value) {
                      setState(() => _zodiac = value);
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
                onPressed: () => widget.onNext(_communicationStyle, _loveLanguage, _educationLevel, _zodiac),
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

  Widget _buildChipGrid(List<String> options, String selected, Function(String) onTap) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map<Widget>((option) {
        return GoldChip(
          label: option,
          selected: selected == option,
          onTap: () => onTap(option),
        );
      }).toList(),
    );
  }
}

// SCREEN 11: Interests
class InterestsScreen extends StatefulWidget {
  final OnboardingData data;
  final Function(List<String>) onNext;

  const InterestsScreen({
    super.key,
    required this.data,
    required this.onNext,
  });

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  List<String> _selectedInterests = [];
  final int _maxInterests = 10;

  @override
  void initState() {
    super.initState();
    _selectedInterests = List.from(widget.data.interests);
  }

  final Map<String, List<String>> _interestCategories = {
    'Creativity': [
      "Photography", "Writing", "Art", "Sketching", "Dance", "Singing", 
      "Cooking", "Freelancing", "Poetry", "Language Exchange"
    ],
    'Fan Favorites': [
      "Harry Potter", "Comic-con", "90s Kid", "NBA", "Anime", "Marvel", 
      "K-Drama", "Manga", "Dungeons & Dragons", "MLB"
    ],
    'Food & Drink': [
      "Sushi", "Pizza", "Biryani", "Street Food", "Foodie", "Home cooking", 
      "Fine dining", "Vegan", "Plant-based", "Food tours"
    ],
    'Gaming': [
      "PlayStation", "Xbox", "E-Sports", "Fortnite", "Mobile Gaming", 
      "League of Legends", "Chess", "Roblox", "Ludo"
    ],
    'Outdoors & Adventure': [
      "Road Trips", "Hiking", "Diving", "Camping", "Travelling", 
      "Jetskiing", "Nature", "Hot Springs", "Walking tours", "Rowing"
    ],
    'Staying In': [
      "Reading", "Binge-Watching TV shows", "Home Workout", 
      "Cooking", "Meditation", "Board games"
    ],
    'TV & Movies': [
      "Action movies", "Crime shows", "Fantasy movies", 
      "Animated movies", "Documentaries", "Rom-coms"
    ],
    'Music': [
      "K-Pop", "Soul music", "Rock music", "Music bands", 
      "Gospel music", "Bhangra", "Jazz", "Hip-Hop"
    ],
    'Values & Causes': [
      "Activism", "Equality", "Human Rights", "Social Development", 
      "Environment", "Mental Health", "LGBTQIA+ Rights"
    ],
    'Wellness & Lifestyle': [
      "Yoga", "Meditation", "Self Care", "Spa", "Trying New Things", 
      "Astrology", "Tarot", "Self Love"
    ],
    'Social & Content': [
      "Instagram", "Podcasts", "YouTube", "Spotify", "Pinterest", 
      "SoundCloud", "Social Media", "X (Twitter)"
    ],
    'Sports & Fitness': [
      "Cricket", "Football", "Basketball", "Tennis", "Swimming", 
      "Freeletics", "Athletics", "Ice Hockey", "Walking"
    ],
  };

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
                  const Text(
                    "What are you into?",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: OnboardingColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            
            // Selected Interests (Horizontal Scroll)
            if (_selectedInterests.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _selectedInterests.length,
                  itemBuilder: (context, index) {
                    final interest = _selectedInterests[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: OnboardingColors.primaryGold.withOpacity(0.1),
                          border: Border.all(color: OnboardingColors.primaryGold),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              interest,
                              style: const TextStyle(
                                color: OnboardingColors.primaryGold,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedInterests.remove(interest);
                                });
                              },
                              child: const Icon(
                                Icons.close,
                                color: OnboardingColors.primaryGold,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: _interestCategories.entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        _SectionHeader(_getEmojiForCategory(entry.key), entry.key),
                        const SizedBox(height: 12),
                        _buildChipGrid(entry.value),
                      ],
                    );
                  }).toList(),
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
                label: "Next ${_selectedInterests.length}/10",
                enabled: _selectedInterests.isNotEmpty,
                onPressed: () => widget.onNext(_selectedInterests),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getEmojiForCategory(String category) {
    final emojiMap = {
      'Creativity': '🎨',
      'Fan Favorites': '⭐',
      'Food & Drink': '🍱',
      'Gaming': '🎮',
      'Outdoors & Adventure': '🌿',
      'Staying In': '🏠',
      'TV & Movies': '🎬',
      'Music': '🎵',
      'Values & Causes': '🌍',
      'Wellness & Lifestyle': '🧘',
      'Social & Content': '📱',
      'Sports & Fitness': '🏅',
    };
    return emojiMap[category] ?? '';
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

  Widget _buildChipGrid(List<String> options) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = _selectedInterests.contains(option);
        return GoldChip(
          label: option,
          selected: isSelected,
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedInterests.remove(option);
              } else if (_selectedInterests.length < _maxInterests) {
                _selectedInterests.add(option);
              }
            });
          },
        );
      }).toList(),
    );
  }
}

// SCREEN 12: Add Photos
class PhotosScreen extends StatefulWidget {
  final OnboardingData data;
  final Future<void> Function(List<String>, String) onNext;

  const PhotosScreen({
    super.key,
    required this.data,
    required this.onNext,
  });

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  List<File> _photos = [];
  final int _minPhotos = 2;
  final int _maxPhotos = 6;

  @override
  void initState() {
    super.initState();
    // Initialize with existing photos if any
    if (widget.data.photos.isNotEmpty) {
      _photos = widget.data.photos.map((path) => File(path)).toList();
    }
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
                "Add your best photos",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: OnboardingColors.textPrimary,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Subtitle
              const Text(
                "Upload 2 photos minimum. 4+ makes your profile stand out.",
                style: TextStyle(
                  fontSize: 16,
                  color: OnboardingColors.textSecondary,
                  height: 1.4,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Photo Grid
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1,
                  ),
                  itemCount: _maxPhotos,
                  itemBuilder: (context, index) {
                    if (index < _photos.length) {
                      // Filled photo slot
                      return _buildPhotoSlot(index, _photos[index]);
                    } else {
                      // Empty photo slot
                      return _buildEmptyPhotoSlot();
                    }
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
                  enabled: _photos.length >= _minPhotos,
                  onPressed: () async {
                    // Convert File objects to paths
                    final photoPaths = _photos.map((file) => file.path).toList();
                    // First image is the profile picture
                    final profilePic = _photos.isNotEmpty ? _photos[0].path : '';
                    await widget.onNext(photoPaths, profilePic);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSlot(int index, File photoFile) {
    final isProfilePic = index == 0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isProfilePic ? OnboardingColors.primaryGold : OnboardingColors.selectedBorder,
          width: isProfilePic ? 3 : 2,
        ),
      ),
      child: Stack(
        children: [
          // Actual image
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              photoFile,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          // Profile picture badge
          if (isProfilePic)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: OnboardingColors.primaryGold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      color: Colors.black,
                      size: 12,
                    ),
                    SizedBox(width: 4),
                    Text(
                      "Profile",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Remove button
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _photos.removeAt(index);
                });
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    if (_photos.length >= _maxPhotos) return;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image != null) {
        setState(() {
          _photos.add(File(image.path));
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  Widget _buildEmptyPhotoSlot() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: OnboardingColors.unselectedBorder,
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.add,
            color: OnboardingColors.textSecondary,
            size: 32,
          ),
        ),
      ),
    );
  }
}

// SCREEN 13: Bio
class BioPromptScreen extends StatefulWidget {
  final OnboardingData data;
  final Function(String) onNext;

  const BioPromptScreen({
    super.key,
    required this.data,
    required this.onNext,
  });

  @override
  State<BioPromptScreen> createState() => _BioPromptScreenState();
}

class _BioPromptScreenState extends State<BioPromptScreen> {
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: widget.data.bio);
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  bool get _isNextEnabled => _bioController.text.trim().isNotEmpty;

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
                "Share more about yourself",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: OnboardingColors.textPrimary,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Subtitle
              const Text(
                "A short bio helps others get to know you.",
                style: TextStyle(
                  fontSize: 16,
                  color: OnboardingColors.textSecondary,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 32),

              // About Me Card
              _buildBioCard(),

              const SizedBox(height: 32),

              // Tip Card
              _buildTipCard(),
              
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
                    _bioController.text.trim(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBioCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: OnboardingColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: OnboardingColors.unselectedBorder,
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "About me",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: OnboardingColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Introduce yourself to make a lasting impression.",
            style: TextStyle(
              fontSize: 14,
              color: OnboardingColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bioController,
            maxLines: 4,
            maxLength: 500,
            style: const TextStyle(
              fontSize: 14,
              color: OnboardingColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: "Write something about yourself...",
              hintStyle: const TextStyle(
                color: OnboardingColors.textSecondary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: OnboardingColors.unselectedBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: OnboardingColors.primaryGold),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OnboardingColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: OnboardingColors.primaryGold,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: OnboardingColors.textSecondary,
                ),
                children: [
                  TextSpan(text: "Adding a short intro could lead to "),
                  TextSpan(
                    text: "40% more profile visits",
                    style: TextStyle(
                      color: OnboardingColors.primaryGold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
