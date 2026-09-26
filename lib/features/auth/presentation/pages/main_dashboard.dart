import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/trial_service.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/helpers/account_suspension_helper.dart';
import 'swipe_page.dart';
import 'messages_view.dart';
import '../../../../services/auth_service.dart';
import 'settings_page.dart';
import '../../../../shared/widgets/gold_button.dart';
import 'profile_screen.dart';
import 'subscription_page.dart';
import 'intent_verification_screen.dart';
import 'set_my_topic_dialog.dart';
// Note: 'marriage_home_page.dart' is no longer used as a tab — the "Home"
// surface was dropped by the 3-tab redesign (Discover / Chat / Profile). No
// replacement landing page is planned; if one is wanted later it's new
// scope, not a migration (per the redesign plan).


class MainDashboard extends StatefulWidget {
  final int initialIndex;
  final Map<String, dynamic>? initialProfileToOpen;

  const MainDashboard({
    super.key,
    this.initialIndex = 0,
    this.initialProfileToOpen,
  });

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  // Opening on the Home page (Index 0)
  late int _currentIndex;
  Timer? _trialCheckTimer;
  bool _linkingDialogVisible = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final blocked = await AccountSuspensionHelper.blockIfSuspended(context);
      if (blocked || !mounted) return;
      await AccountSuspensionHelper.showAppealApprovedIfNeeded(context);
      if (!mounted) return;
      UserService.instance.updateOnlineStatus(true);
      await _checkAndShowLinkingPopup();
      if (!mounted) return;
      await _checkAndShowTopicPopup();
      if (!mounted) return;
      _checkAndShowTrialExpiryBanner();
      if (!mounted) return;
      await IntentVerificationScreen.showIfNeeded(context);
    });

    // Periodically check trial status every 10 seconds
    _trialCheckTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && mounted) {
          await TrialService.checkTrialStatus(user.uid);
        }
      },
    );
  }

  @override
  void dispose() {
    _trialCheckTimer?.cancel();
    super.dispose();
  }


  /// Shows a one-time expiring-trial banner when the trial is on its final day.
  Future<void> _checkAndShowTrialExpiryBanner() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final daysLeft = await TrialService.getTrialDaysLeft(user.uid);
      if (daysLeft == null) return;

      // Only show on final day or less
      if (daysLeft <= 1) {
        final prefs = await SharedPreferences.getInstance();
        const key = 'trial_expiring_shown';
        final alreadyShown = prefs.getBool(key) ?? false;
        if (alreadyShown) return;

        // Mark as shown so it never appears again
        await prefs.setBool(key, true);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Your Premium trial ends soon — upgrade to keep access.",
            ),
            backgroundColor: AppColors.warningRedDark,
            action: SnackBarAction(
              label: 'Upgrade',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionPage()),
                );
              },
            ),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      // Non-critical — ignore errors silently
    }
  }

  Future<void> _checkAndShowLinkingPopup() async {
    final profile = await UserService.instance.getCurrentUserProfile();

    // Internal demo/seed accounts (e.g. seeded for launch/demo purposes) have
    // no real Gmail account behind them, so a genuine Google link is
    // impossible to complete — exempt them from the mandatory-linking
    // requirement rather than leaving them permanently stuck on this dialog.
    // Real user accounts are unaffected.
    if (profile != null && profile['isSeedAccount'] == true) return;

    // Auto-set registrationCompleted if the user is on the dashboard
    if (profile != null && profile['registrationCompleted'] != true) {
      await UserService.instance.updateCurrentUserProfile(<String, dynamic>{
        'registrationCompleted': true,
      });
    }

    if (!mounted || _linkingDialogVisible) return;

    final missing = AuthService.instance.getMissingRequiredLinkLabels();
    if (missing.isEmpty) return;

    // Show every time the user reaches the dashboard without required providers.
    await _showLinkingDialog(missing);
  }

  Future<void> _showLinkingDialog(List<String> missing) async {
    if (!mounted || _linkingDialogVisible) return;
    _linkingDialogVisible = true;

    bool goToSettings = false;
    try {
      goToSettings = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => PopScope(
              canPop: false,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: AlertDialog(
                  backgroundColor: AppColors.obsidian.withOpacity(0.8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(
                      color: AppColors.goldMedium.withOpacity(0.3),
                    ),
                  ),
                  title: const Column(
                    children: [
                      Icon(
                        Icons.security,
                        color: AppColors.goldMedium,
                        size: 48,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Mandatory Account Linking',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'To keep your profile secure, link Google, Email, and Apple (on iPhone) using the same email you registered with.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: missing
                            .map(
                              (m) => Chip(
                                label: Text(
                                  m,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: AppColors.goldMedium,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: 16,
                        left: 16,
                        right: 16,
                      ),
                      child: GoldGradientButton(
                        text: 'LINK NOW',
                        onPressed: () => Navigator.pop(ctx, true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ) ??
          false;
    } finally {
      _linkingDialogVisible = false;
    }

    if (!goToSettings || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SettingsPage(scrollToSecurity: true),
      ),
    );

    // Re-check when user returns — show again if still incomplete.
    if (mounted) {
      await _checkAndShowLinkingPopup();
    }
  }

  /// Shows the "Set My Topic" popup on first login (or any login while it's
  /// still unset) — skippable, so it just reappears next time rather than
  /// blocking the app. Seed/demo accounts are exempt, same as the linking
  /// popup, since they don't need a personal topic to function as demo data.
  Future<void> _checkAndShowTopicPopup() async {
    if (!mounted) return;
    final profile = await UserService.instance.getCurrentUserProfile();
    if (profile == null) return;
    if (profile['isSeedAccount'] == true) return;
    final myTopic = (profile['myTopic'] ?? '').toString().trim();
    if (myTopic.isNotEmpty) return;

    if (!mounted) return;
    await SetMyTopicDialog.show(context);
  }

  void _openUpgradeTab() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubscriptionPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // IndexedStack keeps all tabs mounted so state is preserved when switching.
    // 3-tab redesign: Discover / Chat / Profile. Profile is now an embedded
    // tab body (previously pushed from a top-bar avatar button on the old
    // Home tab, which no longer exists).
    final safeIndex = _currentIndex.clamp(0, 2);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: IndexedStack(
        index: safeIndex,
        children: [
          SwipePage(
            onOpenUpgrade: _openUpgradeTab,
            isTabActive: safeIndex == 0,
          ),
          const MessagesView(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _SwanBottomNav(
        currentIndex: safeIndex,
        onTap: (index) => setState(() => _currentIndex = index.clamp(0, 2)),
      ),
    );
  }
}

// ─── Premium 3-tab bottom nav ─────────────────────────────────────────────────
class _SwanBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _SwanBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(icon: Icons.travel_explore_rounded, activeIcon: Icons.travel_explore_rounded, label: 'Discover'),
      _NavItem(icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Chat', useFaIcon: true),
      _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07), width: 0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 24, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = index == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: item.useFaIcon
                              ? FaIcon(
                                  isSelected ? FontAwesomeIcons.solidComment : FontAwesomeIcons.comment,
                                  key: ValueKey(isSelected),
                                  color: isSelected ? AppColors.goldMedium : Colors.white.withOpacity(0.35),
                                  size: 20,
                                )
                              : Icon(
                                  isSelected ? item.activeIcon : item.icon,
                                  key: ValueKey(isSelected),
                                  color: isSelected ? AppColors.goldMedium : Colors.white.withOpacity(0.35),
                                  size: 24,
                                ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: isSelected ? AppColors.goldMedium : Colors.white.withOpacity(0.35),
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            letterSpacing: 0.2,
                          ),
                          child: Text(item.label),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool useFaIcon;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.useFaIcon = false,
  });
}


class _UpgradePlansPage extends StatefulWidget {
  const _UpgradePlansPage();

  @override
  State<_UpgradePlansPage> createState() => _UpgradePlansPageState();
}

class _UpgradePlansPageState extends State<_UpgradePlansPage> {
  bool _isLoading = false;

  static const _features = [
    'Unlimited Send Interest',
    'See Who Liked You',
    'Advanced Filters',
    'Priority Profile Boost',
    'Chat Area Unlocked'
  ];

  Future<void> _onSubscribe() async {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubscriptionPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ─── Crown Icon ───
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.goldGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.goldMedium.withOpacity(0.4),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.workspace_premium, color: Colors.black, size: 42),
                ),
                const SizedBox(height: 22),

                // ─── Title ───
                const Text(
                  'Upgrade to SWAN Pro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Find your perfect match without limits',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // ─── Feature List Card ───
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Column(
                    children: _features
                        .map(
                          (f) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: AppColors.goldMedium, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    f,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // ─── Pricing Card ───
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.goldMedium.withOpacity(0.22),
                        AppColors.goldLight.withOpacity(0.1),
                      ],
                    ),
                    border: Border.all(color: AppColors.goldMedium.withOpacity(0.4)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.goldMedium.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: AppColors.goldLight, size: 14),
                            SizedBox(width: 5),
                            Text(
                              'Most Popular',
                              style: TextStyle(color: AppColors.goldLight, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Premium Monthly',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '₹2,250',
                        style: TextStyle(
                          color: AppColors.goldLight,
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        '/ month',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Cancel anytime · No hidden fees',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ─── Pay Now Button ───
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _onSubscribe,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.goldMedium,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.workspace_premium, size: 20),
                        SizedBox(width: 10),
                        Text('Subscribe Now — ₹2,250 / mo'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ─── Legal note ───
                Text(
                  'Billed monthly. Cancel anytime from your account settings.',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.55),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.goldMedium),
            ),
          ),
      ],
    );
  }
}