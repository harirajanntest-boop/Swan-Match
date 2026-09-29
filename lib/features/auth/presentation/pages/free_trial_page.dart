import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/iap_service.dart';
import '../../../../shared/widgets/gold_button.dart';
import 'main_dashboard.dart';

/// Displays the free trial offer and allows the user to accept/decline.
/// On acceptance, sets trial fields in Firestore and returns to dashboard.
class FreeTrialPage extends StatefulWidget {
  const FreeTrialPage({super.key});

  @override
  State<FreeTrialPage> createState() => _FreeTrialPageState();
}

class _FreeTrialPageState extends State<FreeTrialPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  bool _isLoading = false;

  // Apple requires the price and billing frequency to be disclosed BEFORE
  // the trial starts, not only on the later paywall screen — these load the
  // real store-localized prices for that disclosure (never hardcoded, since
  // App Store/Play pricing varies by region/currency).
  static const Map<String, String> _priceFallbacks = {
    IapService.monthlyId: '₹2,250',
    IapService.sixMonthId: '₹11,100',
    IapService.yearlyId: '₹22,300',
  };

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );
    _entryController.forward();

    IapService.instance.products.addListener(_onIapProductsChanged);
    IapService.instance.init();
  }

  void _onIapProductsChanged() {
    if (mounted) setState(() {});
  }

  /// Store-localized price for a plan, falling back to a placeholder INR
  /// price only while the store hasn't returned product data yet (e.g. no
  /// network) — same convention as `subscription_page.dart`'s `_iapPrice`.
  String _iapPrice(String planKey) {
    try {
      return IapService.instance.productFor(planKey)?.price ??
          _priceFallbacks[planKey] ??
          '—';
    } catch (_) {
      return _priceFallbacks[planKey] ?? '—';
    }
  }

  @override
  void dispose() {
    IapService.instance.products.removeListener(_onIapProductsChanged);
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _acceptTrial() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final trialEndDate = DateTime.now().add(const Duration(days: 7));
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'subscriptionPlan': 'trial',
        'subscriptionStatus': 'trialing',
        'freeTrialEndsAt': Timestamp.fromDate(trialEndDate),
        'freeTrialStartedAt': Timestamp.now(),
      });

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainDashboard()),
        (route) => false,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _declineTrial() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainDashboard()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: _isLoading
            ? const SizedBox()
            : IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 22),
                onPressed: _declineTrial,
              ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              const Spacer(flex: 1),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.goldMedium.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.diamond_outlined,
                  size: 32,
                  color: AppColors.goldLight,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '7-Day Free Trial',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Premium features — free for 7 days',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 28),
              const _CompactFeature(
                icon: Icons.explore_outlined,
                title: 'More daily swipes & interests',
              ),
              const SizedBox(height: 12),
              const _CompactFeature(
                icon: Icons.chat_bubble_outline,
                title: 'Messaging during trial',
              ),
              const SizedBox(height: 12),
              const _CompactFeature(
                icon: Icons.tune_rounded,
                title: 'Gender & age discover filters',
              ),
              const Spacer(flex: 2),
              // ─── Required disclosure: price + billing frequency BEFORE
              // the trial starts, not only on the later paywall screen.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'After your 7-day free trial, choose a plan:',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PlanPriceRow(label: '1 Month', price: _iapPrice(IapService.monthlyId)),
                    const SizedBox(height: 4),
                    _PlanPriceRow(label: '6 Months', price: _iapPrice(IapService.sixMonthId)),
                    const SizedBox(height: 4),
                    _PlanPriceRow(label: '12 Months', price: _iapPrice(IapService.yearlyId)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The 7-day trial is free: no payment details are needed and nothing is charged. When it ends you move to the Free plan unless you choose to subscribe.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: GoldGradientButton(
                  text: _isLoading ? 'Starting…' : 'START 7-DAY TRIAL',
                  onPressed: _isLoading ? () {} : _acceptTrial,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isLoading ? null : _declineTrial,
                  child: const Text(
                    'MAYBE LATER',
                    style: TextStyle(
                      color: AppColors.goldMedium,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
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

class _PlanPriceRow extends StatelessWidget {
  final String label;
  final String price;

  const _PlanPriceRow({required this.label, required this.price});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
        ),
        Text(
          price,
          style: const TextStyle(
            color: AppColors.goldLight,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CompactFeature extends StatelessWidget {
  final IconData icon;
  final String title;

  const _CompactFeature({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.goldLight, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Icon(Icons.check, color: AppColors.goldMedium, size: 16),
      ],
    );
  }
}
