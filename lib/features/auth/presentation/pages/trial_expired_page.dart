import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../shared/widgets/gold_button.dart';
import 'main_dashboard.dart';
import 'subscription_page.dart';

/// Displays a message when the free trial has expired.
/// Allows the user to upgrade or return to the dashboard.
class TrialExpiredPage extends StatefulWidget {
  const TrialExpiredPage({super.key});

  @override
  State<TrialExpiredPage> createState() => _TrialExpiredPageState();
}

class _TrialExpiredPageState extends State<TrialExpiredPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MainDashboard()),
              (route) => false,
            );
          },
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
                  AppColors.warningRed.withOpacity(0.1),
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
                      // Warning icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.warningRed.withOpacity(0.3),
                              AppColors.warningRedDark.withOpacity(0.1),
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.lock_outline,
                            size: 48,
                            color: AppColors.warningRed,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Title
                      Text(
                        'Trial Expired',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      // Subtitle
                      Text(
                        'Your 21-day Premium trial has ended. Upgrade now to continue enjoying Premium features.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 40),
                      // Benefits recap
                      _BenefitBox(
                        icon: Icons.people,
                        title: 'Browse Unlimited Profiles',
                        subtitle: 'See everyone in your area',
                      ),
                      const SizedBox(height: 12),
                      _BenefitBox(
                        icon: Icons.message,
                        title: 'Send Messages Instantly',
                        subtitle: 'Connect with anyone you like',
                      ),
                      const SizedBox(height: 12),
                      _BenefitBox(
                        icon: Icons.favorite,
                        title: 'Send Unlimited Interest',
                        subtitle: 'Show your interest to anyone',
                      ),
                      const SizedBox(height: 12),
                      _BenefitBox(
                        icon: Icons.verified_user,
                        title: 'Premium Badge',
                        subtitle: 'Stand out with a verified badge',
                      ),
                      const SizedBox(height: 50),
                      // CTA
                      Text(
                        'Continue with Premium',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: GoldGradientButton(
                          text: 'UPGRADE NOW',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SubscriptionPage(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Return to dashboard button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const MainDashboard()),
                              (route) => false,
                            );
                          },
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
                            'RETURN TO DASHBOARD',
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

/// A benefit item showing what Premium offers.
class _BenefitBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _BenefitBox({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.onyx.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.goldMedium.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.goldLight, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
      ),
    );
  }
}
