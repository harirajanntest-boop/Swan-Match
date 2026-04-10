import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/widgets/gold_button.dart';
import 'lifestyle_details_page.dart';

class InterestsPage extends StatefulWidget {
  const InterestsPage({super.key});

  @override
  State<InterestsPage> createState() => _InterestsPageState();
}

class _InterestsPageState extends State<InterestsPage>
    with SingleTickerProviderStateMixin {
  // ─── Animations ────────────────────────────────────────────────────────────
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ─── State ─────────────────────────────────────────────────────────────────
  final Set<String> _selectedInterests = {}; // Stores all selected items

  // Track "Show More" state for different sections
  bool _showAllHobbies = false;
  bool _showAllMusic = false;

  // ─── Mock Data ─────────────────────────────────────────────────────────────
  final List<String> _hobbies = [
    'Acting',
    'Adventure Sports',
    'Alternative Healing',
    'Art / Handicraft',
    'Astrology',
    'Baking',
    'Bike / Car Enthusiast',
    'Bird Watching',
    'Blogging',
    'Board Games',
    'Cooking',
    'Dancing',
    'Fishing',
    'Gardening',
  ];

  final List<String> _music = [
    'Bhangra',
    'Bluegrass',
    'Blues',
    'Christian / Gospel',
    'Classical',
    'Classical - Carnatic',
    'Country',
    'Death Metal',
    'Devotional',
    'Disco',
    'EDM',
    'Hip Hop',
    'Jazz',
    'Pop',
  ];

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  void _toggleInterest(String item) {
    setState(() {
      if (_selectedInterests.contains(item)) {
        _selectedInterests.remove(item);
      } else {
        _selectedInterests.add(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.obsidian,
        appBar: AppBar(
          backgroundColor: AppColors.obsidian,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: AppColors.goldMedium,
              size: 18,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            "Select your interests",
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'serif',
              letterSpacing: 1,
              fontSize: 18,
            ),
          ),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: AppColors.goldMedium,
            indicatorWeight: 3,
            labelColor: AppColors.goldMedium,
            unselectedLabelColor: Colors.white.withOpacity(0.5),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
            tabs: const [
              Tab(text: "Hobbies & Interests"),
              Tab(text: "Music"),
              Tab(text: "Reading"),
              Tab(text: "Movies"),
            ],
          ),
        ),
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Column(
              children: [
                Expanded(
                  child: TabBarView(
                    children: [
                      // ─── TAB 1: Hobbies ───
                      _buildSelectionGrid(
                        title: "Choose Hobbies & Interests",
                        items: _hobbies,
                        showAll: _showAllHobbies,
                        onToggleShowAll: () =>
                            setState(() => _showAllHobbies = !_showAllHobbies),
                      ),

                      // ─── TAB 2: Music ───
                      _buildSelectionGrid(
                        title: "Choose the music genre",
                        items: _music,
                        showAll: _showAllMusic,
                        onToggleShowAll: () =>
                            setState(() => _showAllMusic = !_showAllMusic),
                      ),

                      // ─── TAB 3 & 4: Placeholders for now ───
                      const Center(
                        child: Text(
                          "Reading options coming soon...",
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                      const Center(
                        child: Text(
                          "Movie options coming soon...",
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Bottom Sticky Action Area ───
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.obsidian,
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.05)),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GoldGradientButton(
                          text: "SUBMIT",
                          onPressed: () async {
                            await UserService.instance.updateInterests(
                              _selectedInterests.toList(),
                            );

                            if (!context.mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const LifestyleDetailsPage(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () {
                            // Skip for now
                          },
                          child: Text(
                            "I will do this later",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Reusable Grid Builder ───
  Widget _buildSelectionGrid({
    required String title,
    required List<String> items,
    required bool showAll,
    required VoidCallback onToggleShowAll,
  }) {
    // Show only first 8 items if not expanded
    final displayItems = showAll ? items : items.take(8).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 16,
            children: displayItems.map((item) {
              final isSelected = _selectedInterests.contains(item);
              return _MultiSelectPill(
                label: item,
                isSelected: isSelected,
                onTap: () => _toggleInterest(item),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Show More / Show Less Button
          if (items.length > 8)
            Center(
              child: GestureDetector(
                onTap: onToggleShowAll,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      showAll ? "Show less" : "Show more",
                      style: const TextStyle(
                        color: AppColors.goldMedium,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      showAll
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.goldMedium,
                      size: 18,
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

// ─── Multi-Select Animated Pill ──────────────────────────────────────────────
class _MultiSelectPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MultiSelectPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: isSelected ? AppColors.goldGradient : null,
          color: isSelected ? null : Colors.white.withOpacity(0.02),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : Colors.white.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.goldDark.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white.withOpacity(0.85),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
