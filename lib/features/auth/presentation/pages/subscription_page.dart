import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/widgets/gold_button.dart';
import 'main_dashboard.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ─── State Management ──────────────────────────────────────────────────────
  String _selectedTab = 'Basic'; // Basic vs Assisted
  String _selectedDuration = '3 Months'; // 3 Months, 6 Months, Till U Marry
  String _selectedTier = 'Gold'; // Gold vs Prime

  // ─── Pricing Data (from your screenshots) ──────────────────────────────────
  final Map<String, Map<String, String>> _pricing = {
    "3 Months": {"Gold": "₹ 5,900", "Prime": "₹ 7,900"},
    "6 Months": {"Gold": "₹ 11,900", "Prime": "₹ 14,900"},
    "Till U Marry": {"Gold": "₹ 10,900", "Prime": "₹ 13,900"},
  };

  final List<String> _durations = ["3 Months", "6 Months", "Till U Marry"];

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

  // ─── Dynamic Benefits Logic ───
  List<Map<String, dynamic>> _getBenefits() {
    bool isPrime = _selectedTier == 'Prime';
    bool isTillMarry = _selectedDuration == 'Till U Marry';

    // Logic based on screenshots: Prime or Till U Marry gets unlimited numbers
    String phoneNosText = (isPrime || isTillMarry)
        ? "Unlimited Mobile\nNumbers*"
        : "40 - Mobile Numbers";
    bool govtIdActive = isPrime;

    return [
      {
        "icon": Icons.contact_phone_outlined,
        "title": "View Phone Nos.",
        "subtitle": phoneNosText,
        "active": true,
      },
      {
        "icon": Icons.message_outlined,
        "title": "Send Messages",
        "subtitle": "Unlimited",
        "active": true,
      },
      {
        "icon": Icons.video_call_outlined,
        "title": "Chat & Video Call",
        "subtitle": "Unlimited",
        "active": true,
      },
      {
        "icon": Icons.explore_outlined,
        "title": "View Horoscopes",
        "subtitle": "Unlimited",
        "active": true,
      },
      {
        "icon": Icons.how_to_reg,
        "title": "Govt ID Verified\nMatches",
        "subtitle": isPrime ? "Prime exclusive" : "",
        "active": govtIdActive,
      },
      {
        "icon": Icons.assignment_ind_outlined,
        "title": "Profile Highlighter",
        "subtitle": "30 Days",
        "active": false,
      },
    ];
  }

  String _getDynamicTitle() {
    String tierName = _selectedTier == 'Gold' ? "Gold" : "Prime Gold";
    if (_selectedDuration == "Till U Marry") {
      return "Services & Benefits : $tierName Till U Marry";
    }
    return "Services & Benefits : $tierName";
  }

  @override
  Widget build(BuildContext context) {
    final useRedesignedLayout = ModalRoute.of(context) != null;
    if (useRedesignedLayout) {
      return const _SwanProSubscriptionBody();
    }

    List<Map<String, dynamic>> benefits = _getBenefits();
    String currentGoldPrice = _pricing[_selectedDuration]!["Gold"]!;
    String currentPrimePrice = _pricing[_selectedDuration]!["Prime"]!;

    // Label logic: screenshot shows "PRIME" instead of "PRIME GOLD" for Till U Marry
    String primeLabel = _selectedDuration == "Till U Marry"
        ? "PRIME"
        : "PRIME GOLD";

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Column(
              children: [
                // ─── Top Bar & Money Back Banner ───
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: AppColors.goldMedium,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF0D47A1),
                                Colors.blue.shade800,
                              ], // Deep trust blue
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.thumb_up_alt,
                                color: AppColors.goldLight,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  "21 Days Money Back Guarantee",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.info_outline,
                                color: Colors.white.withOpacity(0.8),
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Tabs (Basic / Assisted) ───
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                  child: Row(
                    children: [_buildTopTab("Basic"), _buildTopTab("Assisted")],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── Dynamic Benefits Section ───
                        Text(
                          _getDynamicTitle(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'serif',
                          ),
                        ),
                        const SizedBox(height: 20),

                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 2.5,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 16,
                              ),
                          itemCount: benefits.length,
                          itemBuilder: (context, index) {
                            final b = benefits[index];
                            bool active = b["active"];
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  b["icon"],
                                  color: active
                                      ? AppColors.goldMedium
                                      : Colors.white.withOpacity(0.2),
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        b["title"],
                                        style: TextStyle(
                                          color: active
                                              ? Colors.white
                                              : Colors.white.withOpacity(0.3),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          height: 1.2,
                                        ),
                                      ),
                                      if (b["subtitle"]
                                          .toString()
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          b["subtitle"],
                                          style: TextStyle(
                                            color: active
                                                ? Colors.white.withOpacity(0.6)
                                                : Colors.white.withOpacity(0.2),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        if (_selectedDuration == "Till U Marry") ...[
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              "Know More >",
                              style: TextStyle(
                                color: AppColors.goldMedium.withOpacity(0.8),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // ─── Selection Container ───
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Column(
                                children: [
                                  // Duration Dropdown
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedDuration,
                                          dropdownColor: AppColors.onyx,
                                          icon: const Icon(
                                            Icons.keyboard_arrow_down,
                                            color: Colors.white54,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          items: _durations
                                              .map(
                                                (d) => DropdownMenuItem(
                                                  value: d,
                                                  child: Text(d),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (v) => setState(
                                            () => _selectedDuration = v!,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Plan Cards Row
                                  Row(
                                    children: [
                                      // Gold Card
                                      Expanded(
                                        child: _SelectablePlanCard(
                                          title: "GOLD",
                                          price: currentGoldPrice,
                                          isSelected: _selectedTier == 'Gold',
                                          onTap: () => setState(
                                            () => _selectedTier = 'Gold',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Prime Card
                                      Expanded(
                                        child: _SelectablePlanCard(
                                          title: primeLabel,
                                          price: currentPrimePrice,
                                          isSelected: _selectedTier == 'Prime',
                                          onTap: () => setState(
                                            () => _selectedTier = 'Prime',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // ─── Pay Now Button ───
                        GoldGradientButton(
                          text: "PAY NOW",
                          onPressed: () async {
                            final plan =
                                '${_selectedTab.toLowerCase()}-${_selectedTier.toLowerCase()}-${_selectedDuration.toLowerCase()}';
                            await UserService.instance.setSubscriptionPlan(plan);

                            if (!context.mounted) return;
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => const MainDashboard()),
                              (route) => false, // Destroys previous history
                            );
                          },
                        ),
                        const SizedBox(height: 20),
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

  // Helper for Top Tabs
  Widget _buildTopTab(String title) {
    bool isSelected = _selectedTab == title;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = title),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.goldMedium : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? AppColors.goldMedium
                    : Colors.white.withOpacity(0.5),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwanProSubscriptionBody extends StatelessWidget {
  const _SwanProSubscriptionBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.black,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.goldGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.goldMedium.withOpacity(0.35),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.workspace_premium, color: Colors.black, size: 40),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Upgrade to SWAN Pro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'serif',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Find your perfect match without limits',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 26),
                _FeatureCard(
                  features: const [
                    'Unlimited Send Interest',
                    'See Who Liked You',
                    'Advanced Filters',
                    'Priority Profile Boost',
                    'Ad-Free Experience',
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.goldMedium.withOpacity(0.22),
                        AppColors.goldLight.withOpacity(0.1),
                      ],
                    ),
                    border: Border.all(color: AppColors.goldMedium.withOpacity(0.35)),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'Monthly Plan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '\$19.99 / month',
                        style: TextStyle(
                          color: AppColors.goldLight,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'serif',
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Cancel anytime',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MainDashboard(initialIndex: 4),
                        ),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.goldMedium,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        fontSize: 16,
                      ),
                    ),
                    child: const Text('Pay Now'),
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const MainDashboard()),
                      (route) => false,
                    );
                  },
                  child: Text(
                    "I'll do it later",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      decoration: TextDecoration.underline,
                      fontSize: 14,
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
}

class _FeatureCard extends StatelessWidget {
  final List<String> features;

  const _FeatureCard({required this.features});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        children: features
            .map(
              (feature) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.goldMedium, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ─── Custom Selectable Plan Card ─────────────────────────────────────────────
class _SelectablePlanCard extends StatelessWidget {
  final String title;
  final String price;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectablePlanCard({
    required this.title,
    required this.price,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.goldMedium.withOpacity(0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.goldMedium
                : Colors.white.withOpacity(0.15),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.goldMedium.withOpacity(0.1),
                    blurRadius: 10,
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              height: 1,
              width: 40,
              color: Colors.white.withOpacity(0.1),
            ),
            Text(
              price,
              style: const TextStyle(
                color: AppColors.goldLight,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'serif',
              ),
            ),
            const SizedBox(height: 32),

            // Custom Radio Button
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.goldMedium
                      : Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.goldMedium,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
