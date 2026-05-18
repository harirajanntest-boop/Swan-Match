import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/constants/colors.dart';
import '../../../../shared/widgets/gold_button.dart';
import '../../../../services/payment_flow_service.dart';
import '../../../../services/stripe_service.dart';
import '../../../../services/user_service.dart';

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
                // Cancel subscription link
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () async {
                        try {
                          final profile = await UserService.instance.getCurrentUserProfile();
                          final sub = (profile?['subscription'] as Map?)?.cast<String, dynamic>();
                          final status = (sub?['status'] ?? '').toString().toLowerCase();
                          final isActive = status == 'active' || status == 'trialing';

                          if (!isActive) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No active subscription to cancel.')),
                              );
                            }
                            return;
                          }

                          if (!mounted) return;
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF111111),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Text('Cancel Subscription', style: TextStyle(color: Colors.white)),
                              content: const Text(
                                'You will be taken to the Stripe Customer Portal where you can cancel or manage your subscription. Continue?',
                                style: TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open Portal')),
                              ],
                            ),
                          );

                          if (confirm != true) return;

                          try {
                            await StripeService.instance.createPortalSession();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error opening portal: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        } catch (_) {}
                      },
                      child: const Text(
                        'Cancel subscription',
                        style: TextStyle(
                          color: Colors.white70,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
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
                            try {
                              // Show loading indicator
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.goldMedium,
                                  ),
                                ),
                              );

                              // Start Stripe subscription
                              await StripeService.instance.startSubscription(
                                priceId: StripeService.premiumMonthlyPriceId,
                              );

                              if (!context.mounted) return;
                              Navigator.pop(context); // Close loading
                            } catch (e) {
                              if (!context.mounted) return;
                              Navigator.pop(context); // Close loading
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
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

class _SwanProSubscriptionBody extends StatefulWidget {
  const _SwanProSubscriptionBody();

  @override
  State<_SwanProSubscriptionBody> createState() =>
      _SwanProSubscriptionBodyState();
}

class _SwanProSubscriptionBodyState extends State<_SwanProSubscriptionBody>
    with WidgetsBindingObserver {
  bool _isLoading = false;
  bool _checkingStatus = true; // true while we check if user is already premium
  bool _isPaidPremium = false;
  bool _isOnFreeTrial = false;
  String _currentPriceId = ''; // The Stripe price ID of the user's active plan
  String _currentPlanTitle = '';
  int _selectedPlanIndex = 2; // Default to 12 Months
  StreamSubscription<Map<String, dynamic>?>? _profileSubscription;
  String _lastProfileSignature = '';
  bool _handlingCheckoutReturn = false;

  // Stripe prices keyed by price ID. Populated on init.
  Map<String, StripePriceInfo> _prices = {};
  bool _pricesLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _profileSubscription = UserService.instance
        .watchCurrentUserProfile()
        .listen(_syncPremiumFromProfile);
    _checkCurrentPremiumStatus();
    _loadPrices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _profileSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleReturnFromCheckout();
    }
  }

  Future<void> _handleReturnFromCheckout() async {
    if (_handlingCheckoutReturn) return;
    final pending = await PaymentFlowService.isCheckoutPending();
    if (!pending) return;

    _handlingCheckoutReturn = true;
    try {
      await PaymentFlowService.presentCongratulationsIfPaid();
    } finally {
      _handlingCheckoutReturn = false;
    }
  }

  /// Fetches the real price amounts from Stripe via Cloud Function.
  Future<void> _loadPrices() async {
    try {
      final prices = await StripeService.instance.fetchPrices([
        StripeService.premiumMonthlyPriceId,
        StripeService.premium6MonthPriceId,
        StripeService.premium1YearPriceId,
      ]);
      if (mounted)
        setState(() {
          _prices = prices;
          _pricesLoading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _pricesLoading = false);
    }
  }

  /// Returns the formatted price for a given price ID, with a fallback.
  String _priceLabel(String priceId, String fallback) {
    final info = _prices[priceId];
    return info != null ? info.formattedAmount : fallback;
  }

  /// Returns the per-month price string for a given price ID.
  String _perMonthLabel(String priceId, String fallback) {
    final info = _prices[priceId];
    return info != null ? info.formattedPerMonth : fallback;
  }

  void _syncPremiumFromProfile(Map<String, dynamic>? profile) {
    final signature = _profileSignature(profile);
    if (signature == _lastProfileSignature) return;
    _lastProfileSignature = signature;

    final status = _subscriptionStatus(profile);
    final priceId = _subscriptionPriceId(profile);
    final currentPlanTitle = _inferCurrentPlanTitle(profile);
    final isPaid = UserService.instance.isPaidPremium(profile);
    final isOnTrial = UserService.instance.isOnFreeTrial(profile);

    int? selectedIndex;
    if (isPaid) {
      if (priceId == StripeService.premiumMonthlyPriceId ||
          currentPlanTitle == '1 Month') {
        selectedIndex = 0;
      } else if (priceId == StripeService.premium6MonthPriceId ||
          currentPlanTitle == '6 Months') {
        selectedIndex = 1;
      } else if (priceId == StripeService.premium1YearPriceId ||
          currentPlanTitle == '12 Months') {
        selectedIndex = 2;
      }
    }

    if (!mounted) return;
    setState(() {
      _isPaidPremium = isPaid;
      _isOnFreeTrial = isOnTrial;
      _currentPriceId = isPaid ? priceId : '';
      _currentPlanTitle = isPaid ? currentPlanTitle : '';
      if (selectedIndex != null) _selectedPlanIndex = selectedIndex;
      _checkingStatus = false;
    });
  }

  String _profileSignature(Map<String, dynamic>? profile) {
    if (profile == null) return '';
    final sub = (profile['subscription'] as Map?)?.cast<String, dynamic>();
    return [
      (sub?['status'] ?? '').toString(),
      (sub?['priceId'] ?? '').toString(),
      (profile['subscriptionStatus'] ?? '').toString(),
      (profile['subscriptionPriceId'] ?? '').toString(),
      (profile['subscriptionPlan'] ?? '').toString(),
      (profile['subscriptionType'] ?? '').toString(),
      (profile['plan'] ?? '').toString(),
      (profile['freeTrialEndsAt'] ?? '').toString(),
    ].join('|');
  }

  String _subscriptionStatus(Map<String, dynamic>? profile) {
    if (profile == null) return '';
    final sub = (profile['subscription'] as Map?)?.cast<String, dynamic>();
    final candidates = <String>[
      profile['subscriptionStatus']?.toString() ?? '',
      sub?['status']?.toString() ?? '',
      profile['status']?.toString() ?? '',
    ].map((s) => s.toLowerCase()).where((s) => s.isNotEmpty);

    for (final status in candidates) {
      if (status == 'active' || status == 'trialing') return status;
    }
    return candidates.isNotEmpty ? candidates.first : '';
  }

  String _subscriptionPriceId(Map<String, dynamic>? profile) {
    if (profile == null) return '';
    final sub = (profile['subscription'] as Map?)?.cast<String, dynamic>();
    return (
      sub?['priceId'] ??
      profile['subscriptionPriceId'] ??
      profile['stripePriceId'] ??
      profile['priceId'] ??
      ''
    ).toString();
  }

  int? _planIndexForPriceId(String priceId) {
    if (priceId == StripeService.premiumMonthlyPriceId) return 0;
    if (priceId == StripeService.premium6MonthPriceId) return 1;
    if (priceId == StripeService.premium1YearPriceId) return 2;
    return null;
  }

  int? _planIndexForTitle(String title) {
    switch (title) {
      case '1 Month':
        return 0;
      case '6 Months':
        return 1;
      case '12 Months':
        return 2;
      default:
        return null;
    }
  }

  bool _isPlanCurrent(int planIndex) {
    if (!_isPaidPremium || _isOnFreeTrial) return false;
    final byPrice = _planIndexForPriceId(_currentPriceId);
    if (byPrice != null) return byPrice == planIndex;
    final byTitle = _planIndexForTitle(_currentPlanTitle);
    if (byTitle != null) return byTitle == planIndex;
    return _selectedPlanIndex == planIndex;
  }

  String _planTitleForPriceId(String priceId) {
    if (priceId == StripeService.premiumMonthlyPriceId) return '1 Month';
    if (priceId == StripeService.premium6MonthPriceId) return '6 Months';
    if (priceId == StripeService.premium1YearPriceId) return '12 Months';
    return '';
  }

  String _inferCurrentPlanTitle(Map<String, dynamic>? profile) {
    if (profile == null) return '';

    final priceId = _subscriptionPriceId(profile);
    final directPlan = _planTitleForPriceId(priceId);
    if (directPlan.isNotEmpty) return directPlan;

    final sub = (profile['subscription'] as Map?)?.cast<String, dynamic>();

    final candidates = [
      profile['subscriptionPlan'],
      profile['subscriptionType'],
      profile['plan'],
      sub?['plan'],
      sub?['subscriptionPlan'],
      sub?['duration'],
      sub?['interval'],
      sub?['billingCycle'],
      sub?['name'],
    ].where((value) => value != null).map((value) => value.toString().toLowerCase()).join(' ');

    if (candidates.contains('1 month') ||
        candidates.contains('monthly') ||
        candidates.contains('month')) {
      return '1 Month';
    }
    if (candidates.contains('6 month') ||
        candidates.contains('6months') ||
        candidates.contains('6 months') ||
        candidates.contains('semi') ||
        candidates.contains('half year')) {
      return '6 Months';
    }
    if (candidates.contains('12 month') ||
        candidates.contains('yearly') ||
        candidates.contains('annual') ||
        candidates.contains('1 year') ||
        candidates.contains('12 months')) {
      return '12 Months';
    }

    return '';
  }

  /// Dynamically calculates savings % by comparing the monthly plan cost
  /// against a multi-month plan cost. Returns e.g. "Save 40%" or empty string.
  String _calculateSavings(
    String monthlyPriceId,
    String otherPriceId,
    int months,
  ) {
    final monthly = _prices[monthlyPriceId];
    final other = _prices[otherPriceId];
    if (monthly == null || other == null) return '';
    final fullPrice = monthly.amount * months;
    if (fullPrice <= 0) return '';
    final savingsPercent = ((fullPrice - other.amount) / fullPrice * 100)
        .round();
    return savingsPercent > 0 ? 'Save $savingsPercent%' : '';
  }

  /// Check Firestore (and Stripe if needed) on page open.
  Future<void> _checkCurrentPremiumStatus() async {
    try {
      final profile = await UserService.instance.getCurrentUserProfile();
      final status = _subscriptionStatus(profile);
      final priceId = _subscriptionPriceId(profile);
      final currentPlanTitle = _inferCurrentPlanTitle(profile);
      final isPaid = UserService.instance.isPaidPremium(profile);
      final isOnTrial = UserService.instance.isOnFreeTrial(profile);
      if (isPaid || isOnTrial) {
        if (mounted) {
          setState(() {
            _isPaidPremium = isPaid;
            _isOnFreeTrial = isOnTrial;
            _currentPriceId = isPaid ? priceId : '';
            _currentPlanTitle = isPaid ? currentPlanTitle : '';
            _checkingStatus = false;
            if (isPaid) {
              final idx = _planIndexForPriceId(priceId) ??
                  _planIndexForTitle(currentPlanTitle);
              if (idx != null) _selectedPlanIndex = idx;
            }
          });
        }
        if (isPaid) return;
        // On free trial — do not call Stripe verify (it can overwrite trial fields).
        if (isOnTrial) return;
      }
      // Free users only: check if they already paid via Stripe outside the app.
      final stripeConfirm = await StripeService.instance
          .verifyAndActivatePremium();
      UserService.instance.invalidateCurrentUserCache();
      if (stripeConfirm) {
        await UserService.instance.endTrialAfterPaidUpgrade();
        final refreshed = await UserService.instance.getCurrentUserProfile();
        final refreshedPriceId = _subscriptionPriceId(refreshed);
        final refreshedPlanTitle = _inferCurrentPlanTitle(refreshed);
        if (mounted) {
          setState(() {
            _isPaidPremium = UserService.instance.isPaidPremium(refreshed);
            _isOnFreeTrial = UserService.instance.isOnFreeTrial(refreshed);
            _currentPriceId = refreshedPriceId;
            _currentPlanTitle = refreshedPlanTitle;
            _checkingStatus = false;
          });
        }
      } else {
        if (mounted)
          setState(() {
            _checkingStatus = false;
          });
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _checkingStatus = false;
        });
    }
  }


  /// Returns the correct Stripe price ID for the currently selected plan.
  String get _selectedPriceId {
    switch (_selectedPlanIndex) {
      case 0:
        return StripeService.premiumMonthlyPriceId;
      case 1:
        return StripeService.premium6MonthPriceId;
      case 2:
      default:
        return StripeService.premium1YearPriceId;
    }
  }

  Future<void> _startPayment() async {
    setState(() => _isLoading = true);
    try {
      // Check current paid premium before charging again.
      final profile = await UserService.instance.getCurrentUserProfile();
      final alreadyPaid = UserService.instance.isPaidPremium(profile);

      if (alreadyPaid) {
        // User already has an active plan — show management dialog.
        if (!mounted) return;
        setState(() => _isLoading = false);
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF111111),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.workspace_premium, color: AppColors.goldMedium),
                SizedBox(width: 8),
                Text(
                  'Premium Active',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: const Text(
              'You already have an active Swan Match Premium subscription. '
              'Would you like to manage or cancel it?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await StripeService.instance.createPortalSession();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text(
                  'Manage',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: AppColors.goldMedium,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
        return;
      }

      await PaymentFlowService.markCheckoutStarted();

      await StripeService.instance.startSubscription(priceId: _selectedPriceId);
      // Deep link fires when user returns from Stripe (handled by _onDeepLink).
      // If launchUrl returns without a deep link (browser closed on Android),
      // stop the spinner after a short delay.
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Manually check Stripe for an existing subscription and activate if found.
  /// Useful when the user paid but the app never got the deep link.
  Future<void> _restorePurchase() async {
    setState(() => _isLoading = true);
    try {
      await StripeService.instance.verifyAndActivatePremium();
      UserService.instance.invalidateCurrentUserCache();
      await UserService.instance.endTrialAfterPaidUpgrade();
      if (!mounted) return;
      final refreshed = await UserService.instance.getCurrentUserProfile();
      final isPaid = UserService.instance.isPaidPremium(refreshed);
      if (isPaid) {
        setState(() {
          _isPaidPremium = true;
          _isOnFreeTrial = UserService.instance.isOnFreeTrial(refreshed);
          _currentPriceId = _subscriptionPriceId(refreshed);
          _currentPlanTitle = _inferCurrentPlanTitle(refreshed);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No active subscription found. Please complete payment first.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // NOTE: When the user is already premium, we no longer show the success
    // screen here. Instead we show the normal subscription page — the
    // _startPayment method already detects active subscriptions and shows
    // the "Premium Active / Manage" dialog if they try to pay again.

    return Scaffold(
      body: Container(
        color: Colors.black,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Back arrow ─────────────────────────────────────────
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Crown icon ─────────────────────────────────────────
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.goldMedium.withOpacity(0.25),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    const FaIcon(
                      FontAwesomeIcons.crown,
                      color: AppColors.goldMedium,
                      size: 48,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Title ──────────────────────────────────────────────
                const Text(
                  'Premium',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Upgrade your experience',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),

                // ── Feature list (centered block, left-aligned items) ─────
                Center(
                  child: SizedBox(
                    width: 240,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        'Unlimited Send Interest',
                        'See Who Liked You',
                        'Advanced Filters',
                        'Priority Profile Boost',
                        'Ad-Free Experience',
                        'Chat & Video Call Unlock',
                      ].map((f) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check,
                              color: AppColors.goldMedium,
                              size: 18,
                            ),
                            const SizedBox(width: 14),
                            Text(
                              f,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                if (_isOnFreeTrial && !_isPaidPremium) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.goldMedium.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.goldMedium.withOpacity(0.35),
                      ),
                    ),
                    child: const Text(
                      'You\'re on a free trial. Choose a plan below to '
                      'upgrade — your trial will end when payment completes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Plan cards (vertical stack) ────────────────────────
                if (_pricesLoading) ...[
                  // Shimmer-style skeleton placeholders while loading
                  for (int i = 0; i < 3; i++) ...[
                    Container(
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    if (i < 2) const SizedBox(height: 10),
                  ],
                ] else ...[
                  // 1 Month
                  _VerticalPlanCard(
                    title: '1 Month',
                    price:
                        _prices[StripeService.premiumMonthlyPriceId]
                            ?.formattedAmount ??
                        'Loading...',
                    isSelected: _selectedPlanIndex == 0,
                    isCurrentPlan: _isPlanCurrent(0),
                    onTap: () => setState(() => _selectedPlanIndex = 0),
                  ),
                  const SizedBox(height: 10),

                  // 6 Months
                  _VerticalPlanCard(
                    title: '6 Months',
                    price:
                        _prices[StripeService.premium6MonthPriceId]
                            ?.formattedAmount ??
                        'Loading...',
                    subtitle: _calculateSavings(
                      StripeService.premiumMonthlyPriceId,
                      StripeService.premium6MonthPriceId,
                      6,
                    ),
                    isSelected: _selectedPlanIndex == 1,
                    isCurrentPlan: _isPlanCurrent(1),
                    onTap: () => setState(() => _selectedPlanIndex = 1),
                  ),
                  const SizedBox(height: 10),

                  // 12 Months — always shows "Most Popular" banner
                  _VerticalPlanCard(
                    title: '12 Months',
                    price:
                        _prices[StripeService.premium1YearPriceId]
                            ?.formattedAmount ??
                        'Loading...',
                    subtitle: _calculateSavings(
                      StripeService.premiumMonthlyPriceId,
                      StripeService.premium1YearPriceId,
                      12,
                    ),
                    isSelected: _selectedPlanIndex == 2,
                    isMostPopular: true,
                    isCurrentPlan: _isPlanCurrent(2),
                    onTap: () => setState(() => _selectedPlanIndex = 2),
                  ),
                ],
                const SizedBox(height: 28),

                // ── CTA / Status ───────────────────────────────────────
                if (_checkingStatus)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(
                      color: AppColors.goldMedium,
                    ),
                  )
                else if (_isPaidPremium) ...[
                  // User already has paid premium — show manage subscription button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.goldMedium),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () async {
                                setState(() => _isLoading = true);
                                try {
                                  await StripeService.instance.createPortalSession();
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                } finally {
                                  if (mounted) setState(() => _isLoading = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: AppColors.goldMedium,
                          disabledBackgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            fontSize: 16,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.goldMedium,
                                ),
                              )
                            : const Text('Manage Subscription'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _isLoading ? null : _restorePurchase,
                    child: Text(
                      'Restore Purchase',
                      style: TextStyle(
                        color: AppColors.goldMedium.withOpacity(0.7),
                        decoration: TextDecoration.underline,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ]
                else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _startPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            fontSize: 16,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text('Continue'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _isLoading ? null : _restorePurchase,
                    child: Text(
                      'Restore Purchase',
                      style: TextStyle(
                        color: AppColors.goldMedium.withOpacity(0.7),
                        decoration: TextDecoration.underline,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
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
    return Column(
      children: features
          .map(
            (feature) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
              child: Row(
                children: [
                  const Icon(
                    Icons.check,
                    color: AppColors.goldMedium,
                    size: 20,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

// ─── Custom Plan Card ─────────────────────────────────────────────
class _PlanOptionCard extends StatelessWidget {
  final String title;
  final String price;
  final String? subtitle;
  final bool isPopular;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanOptionCard({
    required this.title,
    required this.price,
    this.subtitle,
    this.isPopular = false,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.goldMedium : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
          color: isSelected
              ? AppColors.goldMedium.withOpacity(0.05)
              : Colors.black,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: AppColors.goldMedium,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    price,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            if (isPopular)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(15),
                    bottomRight: Radius.circular(15),
                  ),
                ),
                child: const Text(
                  'Most Popular',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.goldMedium : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? AppColors.goldMedium.withValues(alpha: 0.1)
              : Colors.black,
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppColors.goldMedium : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              price,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Vertical stacked plan card (matches Image 3 design) ───────────────────
class _VerticalPlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String? subtitle;
  final bool isSelected;
  final bool isMostPopular;
  final bool isCurrentPlan;
  final VoidCallback onTap;

  const _VerticalPlanCard({
    required this.title,
    required this.price,
    this.subtitle,
    required this.isSelected,
    this.isMostPopular = false,
    this.isCurrentPlan = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.goldMedium : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
          color: isSelected
              ? AppColors.goldMedium.withOpacity(0.06)
              : Colors.black,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isCurrentPlan) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Current Plan',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: AppColors.goldMedium,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    price,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            if (isMostPopular)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(15),
                    bottomRight: Radius.circular(15),
                  ),
                ),
                child: const Text(
                  'Most Popular',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Full-screen subscription success page ──────────────────────────────────
class _SuccessScreen extends StatefulWidget {
  final VoidCallback onHome;
  const _SuccessScreen({required this.onHome});

  @override
  State<_SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<_SuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Couple photo fills entire screen ──────────────────────────
          Image.asset('assets/images/sucess.png', fit: BoxFit.cover),

          // ── Dark gradient at bottom for text readability ──────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.35, 0.65, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.55),
                    Colors.black.withOpacity(0.92),
                  ],
                ),
              ),
            ),
          ),

          // ── Scattered gold confetti dots ──────────────────────────────
          ..._confettiDots(),

          // ── Text + button block ───────────────────────────────────────
          Positioned(
            left: 28,
            right: 28,
            bottom: 56,
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Heading
                    const Text(
                      "Here's to your\nfuture together 💛",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        fontFamily: 'serif',
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Sub-heading
                    const Text(
                      "We're happy for you!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Back to Home button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppColors.goldGradient,
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: ElevatedButton(
                          onPressed: widget.onHome,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              letterSpacing: 0.4,
                            ),
                          ),
                          child: const Text('Back to Home'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Generates a list of small gold confetti circle widgets.
  List<Widget> _confettiDots() {
    const dots = [
      _ConfettiDot(left: 18, top: 90, size: 6),
      _ConfettiDot(left: 55, top: 180, size: 4),
      _ConfettiDot(left: 120, top: 60, size: 5),
      _ConfettiDot(right: 22, top: 110, size: 7),
      _ConfettiDot(right: 68, top: 200, size: 4),
      _ConfettiDot(right: 140, top: 75, size: 5),
      _ConfettiDot(left: 35, bottom: 260, size: 5),
      _ConfettiDot(right: 40, bottom: 280, size: 6),
      _ConfettiDot(left: 80, bottom: 180, size: 4),
      _ConfettiDot(right: 85, bottom: 190, size: 4),
      _ConfettiDot(left: 200, top: 130, size: 4),
      _ConfettiDot(right: 200, bottom: 130, size: 5),
    ];
    return dots;
  }
}

/// A tiny gold confetti dot positioned absolutely.
class _ConfettiDot extends StatelessWidget {
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final double size;

  const _ConfettiDot({
    this.left,
    this.right,
    this.top,
    this.bottom,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.goldMedium.withOpacity(0.75),
        ),
      ),
    );
  }
}
