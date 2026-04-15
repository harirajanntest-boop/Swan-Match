import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/colors.dart';
import '../../../../shared/widgets/gold_button.dart';

/// A 3-screen feature guide shown only once after a new account is created.
/// Uses SharedPreferences with a user-specific key to track per-account.
class FeatureGuidePage extends StatefulWidget {
  /// The page to navigate to after the guide completes.
  final Widget destination;

  const FeatureGuidePage({super.key, required this.destination});

  /// Returns `true` if the guide has already been shown for the current user.
  static Future<bool> hasBeenShown() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return true; // No user logged in → skip guide
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('${_kPrefKey}_$uid') ?? false;
  }

  /// Marks the guide as shown for the current user.
  static Future<void> markAsShown() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_kPrefKey}_$uid', true);
  }

  static const String _kPrefKey = 'feature_guide_shown';

  @override
  State<FeatureGuidePage> createState() => _FeatureGuidePageState();
}

class _FeatureGuidePageState extends State<FeatureGuidePage>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final AnimationController _bgGlowController;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  // ── Guide slide data ───────────────────────────────────────────────────────
  static const List<_GuideSlide> _slides = [
    _GuideSlide(
      image: 'assets/images/guide/couple_welcome.png',
      title: 'Find Your Perfect Match',
      subtitle:
          'Browse thousands of verified Tamil profiles curated just for you. '
          'Your soulmate is just a swipe away.',
      icon: Icons.favorite_rounded,
    ),
    _GuideSlide(
      image: 'assets/images/guide/couple_matching.png',
      title: 'Smart Matching Engine',
      subtitle:
          'Our intelligent algorithm matches you based on horoscope, preferences, '
          'lifestyle, and family values.',
      icon: Icons.auto_awesome_rounded,
    ),
    _GuideSlide(
      image: 'assets/images/guide/couple_celebration.png',
      title: 'Begin Your Forever',
      subtitle:
          'Connect, chat securely, and take the next step towards your dream wedding '
          'with complete privacy.',
      icon: Icons.celebration_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _bgGlowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bgGlowController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
  }

  Future<void> _finishGuide() async {
    await FeatureGuidePage.markAsShown();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => widget.destination),
      (route) => false,
    );
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finishGuide();
    }
  }

  void _skipGuide() => _finishGuide();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          children: [
            // ── Animated background glow ─────────────────────────────────
            AnimatedBuilder(
              animation: _bgGlowController,
              builder: (_, __) {
                final t = _bgGlowController.value;
                return Stack(
                  children: [
                    Positioned(
                      top: -100 + t * 40,
                      right: -80 + t * 30,
                      child: _GlowOrb(
                        size: 300,
                        color: AppColors.goldDark.withOpacity(0.10),
                      ),
                    ),
                    Positioned(
                      bottom: 80 - t * 50,
                      left: -60 + t * 20,
                      child: _GlowOrb(
                        size: 240,
                        color: AppColors.goldMedium.withOpacity(0.06),
                      ),
                    ),
                  ],
                );
              },
            ),

            // ── Page content ─────────────────────────────────────────────
            Column(
              children: [
                // Skip button
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _currentPage < _slides.length - 1
                          ? GestureDetector(
                              onTap: _skipGuide,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color:
                                        AppColors.goldMedium.withOpacity(0.4),
                                  ),
                                  color: Colors.white.withOpacity(0.03),
                                ),
                                child: Text(
                                  'Skip',
                                  style: TextStyle(
                                    color:
                                        AppColors.goldMedium.withOpacity(0.8),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox(height: 38),
                    ),
                  ),
                ),

                // PageView
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _slides.length,
                    itemBuilder: (context, index) {
                      return _GuideSlideWidget(
                        slide: _slides[index],
                        screenSize: size,
                      );
                    },
                  ),
                ),

                // ── Bottom section: indicators + button ───────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                  child: Column(
                    children: [
                      // Page indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _slides.length,
                          (i) => _PageIndicator(isActive: i == _currentPage),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Action button
                      GoldGradientButton(
                        text: _currentPage == _slides.length - 1
                            ? 'GET STARTED'
                            : 'NEXT',
                        onPressed: _nextPage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Slide data model ─────────────────────────────────────────────────────────
class _GuideSlide {
  final String image;
  final String title;
  final String subtitle;
  final IconData icon;

  const _GuideSlide({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

// ─── Individual slide widget ──────────────────────────────────────────────────
class _GuideSlideWidget extends StatelessWidget {
  final _GuideSlide slide;
  final Size screenSize;

  const _GuideSlideWidget({required this.slide, required this.screenSize});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // ── Couple image with golden frame ───────────────────────────
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppColors.goldMedium.withOpacity(0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.goldDark.withOpacity(0.15),
                    blurRadius: 30,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(27),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      slide.image,
                      fit: BoxFit.cover,
                    ),
                    // Bottom gradient overlay for readability
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 120,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AppColors.obsidian.withOpacity(0.8),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Gold shimmer edge at top
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 2,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: AppColors.goldGradient,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── Icon badge ───────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.04),
                    border: Border.all(
                      color: AppColors.goldMedium.withOpacity(0.35),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.goldMedium.withOpacity(0.08),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    slide.icon,
                    color: AppColors.goldMedium,
                    size: 24,
                  ),
                ),

                const SizedBox(height: 20),

                // ── Title ────────────────────────────────────────────────
                Text(
                  slide.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontFamily: 'serif',
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 14),

                // ── Decorative gold line ─────────────────────────────────
                Container(
                  width: 48,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Subtitle ─────────────────────────────────────────────
                Text(
                  slide.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                    height: 1.6,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page indicator dot ───────────────────────────────────────────────────────
class _PageIndicator extends StatelessWidget {
  final bool isActive;
  const _PageIndicator({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      width: isActive ? 28 : 8,
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: isActive ? AppColors.goldGradient : null,
        color: isActive ? null : Colors.white.withOpacity(0.15),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.goldMedium.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
    );
  }
}

// ─── Glow orb ─────────────────────────────────────────────────────────────────
class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(color: color, blurRadius: 80, spreadRadius: 20),
          ],
        ),
      );
}
