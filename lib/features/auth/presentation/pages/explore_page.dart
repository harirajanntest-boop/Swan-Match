import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/user_service.dart';
import 'goal_swipe_page.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage>
    with SingleTickerProviderStateMixin {
  final Stream<Map<String, int>> _countsStream =
      UserService.instance.watchUserCountsByRelationshipGoal();

  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Curves.easeOut,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Explore',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.bookmark_border, color: AppColors.goldMedium),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GoalSwipePage(goalTitle: 'Ready to Marry'),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Featured card - Ready to Marry (larger)
              StreamBuilder<Map<String, int>>(
                stream: _countsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _GoalCard(
                      icon: Icons.diamond,
                      title: 'Ready to Marry',
                      subtitle: 'Serious profiles only',
                      count: 0,
                      isFeatured: true,
                    );
                  }
                  if (!snapshot.hasData) {
                    return _GoalCard(
                      icon: Icons.diamond,
                      title: 'Ready to Marry',
                      subtitle: 'Serious profiles only',
                      count: 0,
                      isFeatured: true,
                    );
                  }
                  final counts = snapshot.data ?? {};
                  return _GoalCard(
                    icon: Icons.diamond,
                    title: 'Ready to Marry',
                    subtitle: 'Serious profiles only',
                    count: counts['Ready to Marry'] ?? 0,
                    isFeatured: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GoalSwipePage(goalTitle: 'Ready to Marry'),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              // Grid of other goals - fill remaining space
              Expanded(
                child: StreamBuilder<Map<String, int>>(
                  stream: _countsStream,
                  builder: (context, snapshot) {
                    final counts = snapshot.hasData ? snapshot.data! : {};
                    return GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.77,
                      children: [
                        _GoalCard(
                          icon: Icons.handshake,
                          title: 'Something Serious',
                          count: counts['Something Serious'] ?? 0,
                          gradientColors: [
                            Colors.green.withOpacity(0.2),
                            Colors.teal.withOpacity(0.1),
                            Colors.transparent,
                          ],
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const GoalSwipePage(goalTitle: 'Something Serious'),
                              ),
                            );
                          },
                        ),
                        _GoalCard(
                          icon: Icons.favorite,
                          title: 'Long-term Partner',
                          count: counts['Long-term Partner'] ?? 0,
                          gradientColors: [
                            Colors.blue.withOpacity(0.2),
                            Colors.cyan.withOpacity(0.1),
                            Colors.transparent,
                          ],
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const GoalSwipePage(goalTitle: 'Long-term Partner'),
                              ),
                            );
                          },
                        ),
                        _GoalCard(
                          icon: Icons.visibility,
                          title: 'Just Browsing',
                          count: counts['Just Browsing'] ?? 0,
                          gradientColors: [
                            Colors.purple.withOpacity(0.2),
                            Colors.pinkAccent.withOpacity(0.1),
                            Colors.transparent,
                          ],
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const GoalSwipePage(goalTitle: 'Just Browsing'),
                              ),
                            );
                          },
                        ),
                        _GoalCard(
                          icon: Icons.favorite_border,
                          title: 'Let Love Lead',
                          count: counts['Let Love Lead'] ?? 0,
                          gradientColors: [
                            Colors.white.withOpacity(0.15),
                            Colors.grey.withOpacity(0.1),
                            Colors.transparent,
                          ],
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const GoalSwipePage(goalTitle: 'Let Love Lead'),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final int count;
  final bool isFeatured;
  final String? backgroundImage;
  final List<Color>? gradientColors;
  final VoidCallback? onTap;

  const _GoalCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.count,
    this.isFeatured = false,
    this.backgroundImage,
    this.gradientColors,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.goldMedium.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.goldMedium.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            if (isFeatured)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.pink.withOpacity(0.2),
                          Colors.pinkAccent.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (backgroundImage != null)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradientColors ?? [
                          Colors.green.withOpacity(0.2),
                          Colors.teal.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: isFeatured
                  ? const EdgeInsets.all(24.0)
                  : const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        icon,
                        size: isFeatured ? 56 : 40,
                        color: AppColors.goldMedium,
                      ),
                      _ProfileCountBadge(count: count),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isFeatured ? 20 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: AppColors.goldMedium,
                        fontSize: isFeatured ? 14 : 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCountBadge extends StatelessWidget {
  final int count;

  const _ProfileCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.goldMedium.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.goldMedium.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_outline,
            size: 14,
            color: AppColors.goldMedium,
          ),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: TextStyle(
              color: AppColors.goldMedium,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
