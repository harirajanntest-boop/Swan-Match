import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/colors.dart';
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
  late final Animation<Offset> _slideAnim;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
        );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _acceptTrial() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final trialEndDate = DateTime.now().add(const Duration(days: 7));
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
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

  Future<void> _declineTrial() async {
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isLoading
            ? const SizedBox()
            : IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _declineTrial,
              ),
      ),
      body: Stack(
        children: [
          // Animated background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.goldMedium.withOpacity(0.1),
                  AppColors.obsidian,
                ],
              ),
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    children: [
                      const SizedBox(height: 60),
                      // Crown icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.goldLight.withOpacity(0.3),
                              AppColors.goldMedium.withOpacity(0.1),
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.diamond,
                            size: 48,
                            color: AppColors.goldLight,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Title
                      Text(
                        'Unlock Premium',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      // Subtitle
                      Text(
                        'Enjoy 7 days of Premium features for free',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 40),
                      // Feature list
                      _FeatureItem(
                        icon: Icons.check_circle_outline,
                        title: 'Browse Unlimited Profiles',
                        subtitle: 'No daily limits',
                      ),
                      const SizedBox(height: 20),
                      _FeatureItem(
                        icon: Icons.favorite_outline,
                        title: 'Send Interest',
                        subtitle: 'Unlimited interest sends',
                      ),
                      const SizedBox(height: 20),
                      _FeatureItem(
                        icon: Icons.mail_outline,
                        title: 'Send Messages',
                        subtitle: 'Message anyone instantly',
                      ),
                      const SizedBox(height: 20),
                      _FeatureItem(
                        icon: Icons.verified,
                        title: 'Premium Badge',
                        subtitle: 'Stand out with a verified badge',
                      ),
                      const SizedBox(height: 50),
                      // Info box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.infoBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.infoBorder),
                        ),
                        child: Text(
                          'Your trial will auto-renew to Premium after 7 days. You can cancel anytime.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textMuted,
                              ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Accept button
                      SizedBox(
                        width: double.infinity,
                        child: GoldGradientButton(
                          text: _isLoading ? 'Starting Trial...' : 'START 7-DAY TRIAL',
                          onPressed: _isLoading ? () {} : _acceptTrial,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Decline button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _declineTrial,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: AppColors.goldMedium,
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'MAYBE LATER',
                            style: TextStyle(
                              color: AppColors.goldMedium,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single feature item in the trial offer list.
class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.goldLight, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
