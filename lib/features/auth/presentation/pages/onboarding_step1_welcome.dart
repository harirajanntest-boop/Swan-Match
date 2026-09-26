import 'package:flutter/material.dart';
import '../../../../models/onboarding_data.dart';
import '../../../../shared/widgets/onboarding_widgets.dart';

class OnboardingStep1Welcome extends StatelessWidget {
  final OnboardingData data;
  final VoidCallback onNext;

  const OnboardingStep1Welcome({
    super.key,
    required this.data,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Headline
          const Text(
            'Welcome to Swan Match',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: OnboardingColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 12),

          // Tagline / Subtitle
          Text(
            'Real Introductions. Real Connections.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: OnboardingColors.primaryGold,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 20),

          // Description Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: OnboardingColors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            child: Text(
              'Show who you are before you say a word. Record a short intro video, connect over real topics, and only start chatting once you\'re both genuinely interested.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: OnboardingColors.textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Feature Highlights
          _buildFeatureRow(
            icon: Icons.videocam_rounded,
            title: 'Video-First Profiles',
            subtitle: 'Your intro video is your identity — not just photos.',
          ),
          const SizedBox(height: 16),
          _buildFeatureRow(
            icon: Icons.forum_rounded,
            title: 'Topic-Based Connections',
            subtitle: 'Respond to a real question before you ever match.',
          ),
          const SizedBox(height: 16),
          _buildFeatureRow(
            icon: Icons.verified_user_rounded,
            title: 'No Swiping, No Guessing',
            subtitle: 'Every connection starts with a real conversation, not a swipe.',
          ),

          const SizedBox(height: 40),

          // Action CTA
          NextButton(
            label: 'Get Started',
            onPressed: onNext,
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: OnboardingColors.primaryGold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: OnboardingColors.primaryGold,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: OnboardingColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: OnboardingColors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
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
