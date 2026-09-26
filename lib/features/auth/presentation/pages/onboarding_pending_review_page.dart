import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../shared/widgets/onboarding_widgets.dart';
import 'free_trial_page.dart';

/// Terminal screen shown right after onboarding submits the intro video
/// (`introVideoStatus == 'pending'`), replacing the old direct jump to
/// `FreeTrialPage`. The user proceeds into the existing post-onboarding flow
/// from here once acknowledged — `FreeTrialPage` remains the next destination,
/// just with this screen inserted in front of it.
class OnboardingPendingReviewPage extends StatelessWidget {
  const OnboardingPendingReviewPage({super.key});

  void _proceed(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const FreeTrialPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.goldMedium.withOpacity(0.15),
                  border: Border.all(color: AppColors.goldMedium, width: 2),
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  color: AppColors.goldMedium,
                  size: 40,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Your intro video is being reviewed',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'You\'ll be notified once it\'s approved and your profile goes live on Discover. This usually takes less than 24 hours.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              NextButton(
                label: 'Continue',
                onPressed: () => _proceed(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
